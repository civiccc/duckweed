require 'rspec'
require 'rack/test'

require 'mock_redis'

$LOAD_PATH.unshift(File.expand_path(File.join(__FILE__, "..", "..", "lib")))
require 'duckweed'
Dir['spec/shared/*.rb'].each {|shared| require shared}

module SpecHelpers
  def event_happened(params={})
    event_name  = params[:event] || event
    event_time  = params[:at]
    event_count = params[:times] || 1

    event_count.times do
      params = default_params.dup
      if event_time
        params.merge!(:timestamp => event_time.to_i)
      end
      post "/track/#{event_name}", params
    end
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
    Duckweed.redis.reset!
  end
end
