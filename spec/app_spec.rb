require "spec_helper"

describe Duckweed::App do
  def app
    described_class
  end

  it "says hello to the world" do
    get '/hello'
    last_response.body.should =~ /world/i
  end

  describe "POST /track/:event" do
    before do
      @now = Time.now
      Time.stub!(:now).and_return(@now)
    end

    it "accepts requests for new events" do
      post "/track/test-event-71339"
      last_response.should be_successful
      last_response.body.should == "OK"
    end

    it "accepts requests for known events" do
      2.times { post "/track/test-event-47781" }
      last_response.should be_successful
      last_response.body.should == "OK"
    end

    it "increments a key with minute-granularity in Redis" do
      post "/track/test-incr"
      Duckweed.redis.get("duckweed:test-incr:minutes:#{@now.to_i / 60}").should == 1

      post "/track/test-incr"
      Duckweed.redis.get("duckweed:test-incr:minutes:#{@now.to_i / 60}").should == 2
    end

    it "increments a key with hour-granularity in Redis" do
      post "/track/test-incr"
      Duckweed.redis.get("duckweed:test-incr:hours:#{@now.to_i / 3600}").should == 1

      post "/track/test-incr"
      Duckweed.redis.get("duckweed:test-incr:hours:#{@now.to_i / 3600}").should == 2
    end

    it "increments a key with day-granularity in Redis" do
      post "/track/test-incr"
      Duckweed.redis.get("duckweed:test-incr:days:#{@now.to_i / 86400}").should == 1

      post "/track/test-incr"
      Duckweed.redis.get("duckweed:test-incr:days:#{@now.to_i / 86400}").should == 2
    end
  end
end
