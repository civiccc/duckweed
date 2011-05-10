require 'duckweed'
require 'duckweed/utility_methods'
require 'json'
require 'sinatra'

module Duckweed
  # we use different tokens for internal/external use so that we
  # can revoke tokens given to third parties without affecting our apps
  AUTH_TOKENS = [
    'secret_token', # internal use
    'secret_token'  # Geckboard
  ]

  class App < Sinatra::Base
    include UtilityMethods

    # the authentication token, if any, will come in as a param (for example,
    # via a POST to the /track/:event action) or as an HTTP Basic Authentication
    # username (eg. when we're queried by Geckoboard)
    before do
      @auth = auth_token_via_params || auth_token_via_http_basic_auth
    end

    post '/track/:event' do
      if authenticated?
        increment_counters_for(params[:event])
        'OK'
      else
        [403, 'Forbidden']
      end
    end

    get '/count/:event' do
      # default to last hour with minute-granularity
      count_for(params[:event], :minutes, 60)
    end

    get '/count/:event/:granularity/:quantity' do
      granularity = params[:granularity].to_sym
      if !(interval = INTERVAL[granularity])
        [400, 'Bad Request']
      elsif (params[:quantity].to_i * interval[:bucket_size]) > interval[:expiry]
        [413, 'Request Entity Too Large']
      else
        count_for(params[:event], granularity, params[:quantity])
      end
    end

    get '/histogram/:event' do
      if authenticated?
        histogram(params[:event], :minutes, '60')
      else
        [403, 'Forbidden']
      end
    end

    get '/histogram/:event/:granularity/:quantity' do
      granularity = params[:granularity].to_sym
      if authenticated?
        if !(interval = INTERVAL[granularity])
          [400, 'Bad Request']
        elsif (params[:quantity].to_i * interval[:bucket_size]) > interval[:expiry]
          [413, 'Request Entity Too Large']
        else
          histogram(params[:event], granularity, params[:quantity])
        end
      else
        [403, 'Forbidden']
      end
    end

    get "/hello" do
      "Hello, world!"
    end

    private

    def redis
      Duckweed.redis
    end

    def authenticated?
      AUTH_TOKENS.include?(@auth)
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

    def increment_counters_for(event)
      INTERVAL.keys.each do |granularity|
        key = key_for(event, granularity)
        redis.incr(key)
        redis.expire(key, INTERVAL[granularity][:expiry])
      end
    end

    def key_for(event, granularity)
      "duckweed:#{event}:#{bucket_with_granularity(granularity)}"
    end

    def bucket_with_granularity(granularity)
      "#{granularity}:#{bucket_index(granularity)}"
    end

    def bucket_index(granularity)
      time = params[:timestamp] || Time.now
      time.to_i / INTERVAL[granularity][:bucket_size]
    end

    def count_for(event, granularity, quantity)
      keys = keys_for(event, granularity, quantity)
      redis.mget(*keys).inject(0) { |memo, obj| memo + obj.to_i }.to_s
    end

    def keys_for(event, granularity, quantity)
      count = quantity ? quantity.to_i : INTERVAL[granularity][:expiry]
      bucket_indices(granularity, count).map do |idx|
        "duckweed:#{event}:#{granularity}:#{idx}"
      end
    end

    def bucket_indices(granularity, count)
      bucket_idx = bucket_index(granularity)
      Array.new(count) do |i|
        idx = bucket_idx
        bucket_idx -= 1
        idx
      end
    end

    def histogram(event, granularity, quantity)
      keys      = keys_for(event, granularity, quantity)
      values    = redis.mget(*keys).map {|x| x ? x.to_i : 0}
      times     = times_for(granularity, quantity)
      min, max  = values.min, values.max
      mid       = (max - min).to_f / 2
      {
        :item     => values,
        :settings => {
          :axisx  => times,
          :axisy  => [min, mid, max],
          :colour => 'ff9900'
        }
      }.to_json
    end

    def times_for(granularity, quantity)
      ending    = Time.now.to_i
      beginning = ending.to_i - INTERVAL[granularity][:bucket_size] * quantity.to_i
      middle    = (beginning + ending) / 2
      [beginning, middle, ending].map do |time|
        Time.at(time).strftime(INTERVAL[granularity][:time_format])
      end
    end
  end
end
