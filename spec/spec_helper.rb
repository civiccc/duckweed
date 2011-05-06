require 'rspec'
require 'rack/test'

require 'mock_redis'

$LOAD_PATH.unshift(File.expand_path(File.join(__FILE__, "..", "..", "lib")))
require 'duckweed'

module SpecHelpers
  def open_page_in_browser
    path = "/tmp/duckweed_sample_#{$$}.html"
    File.open(path, 'w') do |f|
      f.write(last_response.body)
    end
    `which open && open #{path}`
  end
end

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  conf.include SpecHelpers

  conf.before(:all) do
    Duckweed.redis = MockRedis.new
  end

  conf.before(:each) do
    Duckweed.redis.reset!
  end
end
