require 'sinatra'

module Duckweed
  # We use an auth token not for security (Duckweed will run behind
  # the bastion host anyway) but to prevent accidental updates.
  AUTH_TOKEN = 'c72b8b30ef809fcb866e057a9c12bd5c8a329a3a'

  class App < Sinatra::Base

    post '/track/:event' do
      if authenticated?
        increment_counters_for(params[:event])
        'OK'
      else
        [403, 'FORBIDDEN']
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
      bucket = bucket_with_granularity(granularity)
      "duckweed:#{event}:#{bucket}"
    end

    def bucket_with_granularity(granularity)
      time = params[:timestamp] || Time.now
      bucket_idx = time.to_i / INTERVAL[granularity][:bucket_size]
      "#{granularity}:#{bucket_idx}"
    end
  end
end
