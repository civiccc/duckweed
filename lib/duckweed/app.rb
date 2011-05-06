require 'sinatra'

module Duckweed
  class App < Sinatra::Base

    get "/hello" do
      "Hello, world!"
    end
  end
end
