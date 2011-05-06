require 'rspec'
require 'rack/test'

require 'mock_redis'

$LOAD_PATH.unshift(File.expand_path(File.join(__FILE__, "..", "..", "lib")))
require 'duckweed'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods

  conf.before(:all) do
    Duckweed.redis = MockRedis.new
  end

  conf.before(:each) do
    Duckweed.redis.reset!
  end

end
