require 'sinatra'

module Duckweed
  class App < Sinatra::Base

    post "/track/:event" do
      redis.incr(key_for(params[:event]))
      "OK"
    end

    get "/hello" do
      "Hello, world!"
    end

    private

    def key_for(event, time = Time.now)
      "duckweed:#{event}:#{time.to_i}"
    end

    def redis
      Duckweed.redis
    end

  end
end
