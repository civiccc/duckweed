require 'redis'

module Duckweed
  autoload :App, "duckweed/app"
  autoload :Token, "duckweed/token"

  class << self
    attr_accessor :redis
  end

  begin
    self.redis = Redis.new
  rescue Errno::ECONNREFUSED
    # do nothing; we'll just have a nil redis
  end
end
