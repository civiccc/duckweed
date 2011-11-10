ENV['RACK_ENV'] = 'test'
require 'rspec'
require 'rack/test'

require 'mock_redis'

$LOAD_PATH.unshift(File.expand_path(File.join(__FILE__, "..", "..", "lib")))
require 'duckweed'
Dir['spec/shared/*.rb'].each {|shared| require shared}

MINUTE = 60
HOUR   = 60 * MINUTE
DAY    = 24 * HOUR

module SpecHelpers
  def event_happened(params={})
    event_name  = params[:event] || event
    event_time  = params[:at]
    event_count = params[:times]
    event_group = params[:group]

    params = default_params.dup
    params.merge!(:timestamp => event_time.to_i) if event_time
    params.merge!(:quantity => event_count) if event_count
    params.merge!(:group => event_group) if event_group

    post "/track/#{event_name}", params
    last_response.should be_successful
  end

  def freeze_time
    @now = Time.now
    Time.stub!(:now).and_return(@now)
  end

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
    Duckweed.redis.flushall
  end
end
