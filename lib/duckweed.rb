require 'redis'

module Duckweed
  autoload :App, "duckweed/app"

  class << self
    attr_accessor :redis
  end

  begin
    self.redis = Redis.new
  rescue Errno::ECONNREFUSED
    # do nothing; we'll just have a nil redis
  end
end
