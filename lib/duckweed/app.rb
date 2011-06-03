require 'duckweed'
require 'duckweed/notify_hoptoad'
require 'duckweed/utility_methods'
require 'json'
require 'sinatra'
require 'hoptoad_notifier'

module Duckweed
  # we use different tokens for internal/external use so that we
  # can revoke tokens given to third parties without affecting our apps
  AUTH_TOKENS = [
    'c72b8b30ef809fcb866e057a9c12bd5c8a329a3a', # internal use
    '582ace6fb12518d7c9ee7d26adbbc42bfca5650c', # Geckoboard
    'gYfro0crkACUiJqBz8Di2PK5JZyESI25agroCFst'  # Pingdom
  ]

  class App < Sinatra::Base
    include UtilityMethods
    extend NotifyHoptoad

    # routes accessible without authentication:
    AUTH_WHITELIST = ['/health']

    before do
      unless AUTH_WHITELIST.include?(request.path_info) || authenticated?
        halt 403, 'Forbidden'
      end
    end

    get '/check/:event' do
      require_threshold!
      check_threshold(params[:event], :minutes, 60)
    end

    get '/check/:event/:granularity/:quantity' do
      require_threshold!
      check_request_limits!
      check_threshold(params[:event], params[:granularity].to_sym, params[:quantity].to_i)
    end

    get '/count/:event' do
      # default to last hour with minute-granularity
      count_for(params[:event], :minutes, 60)
    end

    get '/count/:event/:granularity/:quantity' do
      check_request_limits!
      count_for(params[:event], params[:granularity].to_sym, params[:quantity].to_i)
    end

    # Useful for testing Hoptoad notifications
    get '/exception' do
      raise RuntimeError, "wheeeeeeeeeeeeeeeeeeee"
    end

    get '/health' do
      'OK'
    end

    get '/histogram/:event' do
      histogram(params[:event], :minutes, 60)
    end

    get '/histogram/:event/:granularity/:quantity' do
      check_request_limits!
      histogram(params[:event], params[:granularity].to_sym, params[:quantity].to_i)
    end

    get '/accumulate/:event' do
      accumulate(params[:event], :minutes, 60)
    end

    get '/accumulate/:event/:granularity/:quantity' do
      check_request_limits!
      accumulate(params[:event], params[:granularity].to_sym, params[:quantity].to_i)
    end


    post '/track/:event' do
      increment_counters_for(params[:event])
      'OK'
    end

    private

    def redis
      Duckweed.redis
    end

    def authenticated?
      AUTH_TOKENS.include?(auth_token_via_params || auth_token_via_http_basic_auth)
    end

    def auth_token_via_params
      params[:auth_token]
    end

    def auth_token_via_http_basic_auth
      auth = Rack::Auth::Basic::Request.new(request.env)
      auth.provided? && auth.basic? && auth.credentials.first
    end

    INTERVAL = {
      :minutes => {
        :bucket_size  => 60,
        :expiry       => 86400,       # keep minute-resolution data for last day
        :time_format  => '%I:%M%p'    # 10:11AM
      },
      :hours => {
        :bucket_size  => 3600,
        :expiry       => 86400 * 7,   # keep hour-resolution data for last week
        :time_format  => '%a %I%p'    # Sun 10AM
      },
      :days => {
        :bucket_size  => 86400,
        :expiry       => 86400 * 365, # keep day-resolution data for last year
        :time_format  => '%b %d %Y'   # Jan 21 2011
      }
    }

    # don't allow requests that would place an unreasonable load on the server,
    # or for which we won't have data anyway
    def check_request_limits!
      granularity = params[:granularity].to_sym
      if !(interval = INTERVAL[granularity])
        halt 400, 'Bad Request'
      elsif (params[:quantity].to_i * interval[:bucket_size]) > interval[:expiry]
        halt 413, 'Request Entity Too Large'
      end
    end

    def increment_counters_for(event)
      INTERVAL.keys.each do |granularity|
        key = key_for(event, granularity)
        if has_bucket_for?(granularity)
          if params[:quantity]
            redis.incrby(key, params[:quantity].to_i)
          else
            redis.incr(key)
          end
          redis.expire(key, INTERVAL[granularity][:expiry])
        end
      end
    end

    def key_for(event, granularity)
      "duckweed:#{event}:#{bucket_with_granularity(granularity)}"
    end

    def bucket_with_granularity(granularity)
      "#{granularity}:#{bucket_index(granularity)}"
    end

    def bucket_index(granularity)
      timestamp / INTERVAL[granularity][:bucket_size]
    end

    def timestamp
      (params[:timestamp] || Time.now).to_i
    end

    def count_for(event, granularity, quantity)
      keys = keys_for(event, granularity.to_sym, quantity)
      redis.mget(*keys).inject(0) { |memo, obj| memo + obj.to_i }.to_s
    end

    def keys_for(event, granularity, quantity)
      count = quantity ? quantity.to_i : INTERVAL[granularity][:expiry]
      bucket_indices(granularity, count).map do |idx|
        "duckweed:#{event}:#{granularity}:#{idx}"
      end
    end

    def max_buckets(granularity)
      INTERVAL[granularity][:expiry] / INTERVAL[granularity][:bucket_size]
    end

    def bucket_indices(granularity, count)
      bucket_idx = bucket_index(granularity) - count - (params[:offset] || 1).to_i
      Array.new(count) do |i|
        bucket_idx += 1
      end
    end

    def require_threshold!
      threshold = params[:threshold]
      if threshold.nil? || threshold.empty?
        halt 400, 'ERROR: Must provide threshold'
      end
    end

    def check_threshold(event, granularity, quantity)
      threshold = params[:threshold]
      count = count_for(event, granularity, quantity)
      if count.to_i >= threshold.to_i
        "GOOD: #{count}"
      else
        "BAD: #{count} < #{threshold}"
      end
    end

    def has_bucket_for?(granularity)
      first_available_bucket_time = Time.now.to_i - INTERVAL[granularity][:expiry]
      first_available_bucket_time < timestamp
    end

    def histogram(event, granularity, quantity)
      values, times = values_and_times_for(granularity, event, quantity)
      geckoboard_jsonify(values, times)
    end

    def accumulate(event, granularity, quantity)

      # Fetch all the unexpired data we have, so that we can start counting from "1"
      values, times = values_and_times_for(granularity, event, max_buckets(granularity))

      # massage the values to be cumulative
      values = values.inject([]) do |result, element|
        result << result.last.to_i + element
      end

      # return only the quantity we asked for
      geckoboard_jsonify(values[-quantity.to_i..-1], times[-quantity.to_i..-1])
    end

    def times_for(granularity, quantity)
      ending    = Time.now.to_i
      beginning = ending.to_i - INTERVAL[granularity][:bucket_size] * quantity.to_i
      middle    = (beginning + ending) / 2
      [beginning, middle, ending].map do |time|
        Time.at(time).strftime(INTERVAL[granularity][:time_format])
      end
    end

    def values_and_times_for(granularity, event, quantity)
      keys        = keys_for(event, granularity, quantity)
      values      = redis.mget(*keys).map(&:to_i)
      times       = times_for(granularity, quantity)
      [values, times]
    end

    def geckoboard_jsonify(values, times)
      min, max    = values.min, values.max
      mid         = (max - min).to_f / 2
      {
        :item     => values,
        :settings => {
          :axisx  => times,
          :axisy  => [min, mid, max],
          :colour => 'ff9900'
        }
      }.to_json
    end

  end
end
