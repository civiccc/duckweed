require 'sinatra'
require 'duckweed'

module Duckweed
  # We use an auth token not for security (Duckweed will run behind
  # the bastion host anyway) but to prevent accidental updates.
  AUTH_TOKEN = 'secret_token'

  class App < Sinatra::Base

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

    get "/hello" do
      "Hello, world!"
    end

    private

    def redis
      Duckweed.redis
    end

    def authenticated?
      params[:auth_token] == AUTH_TOKEN
    end

    INTERVAL = {
      :minutes => {
        :bucket_size  => 60,
        :expiry       => 86400        # keep minute-resolution data for last day
      },
      :hours => {
        :bucket_size  => 3600,
        :expiry       => 86400 * 7    # keep hour-resolution data for last week
      },
      :days => {
        :bucket_size  => 86400,
        :expiry       => 86400 * 365  # keep day-resolution data for last year
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
  end
end
