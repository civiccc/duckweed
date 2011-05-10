require "spec_helper"

describe Duckweed::App do
  let(:event) { 'test-event-47781' }
  let(:app) { described_class }
  let(:default_params) { {:auth_token => Duckweed::AUTH_TOKEN} }

  before do
    @now = Time.now
    Time.stub!(:now).and_return(@now)
  end

  it "says hello to the world" do
    get '/hello'
    last_response.body.should =~ /world/i
  end

  describe "POST /track/:event" do
    context 'without an authentication token' do
      it 'fails' do
        post "/track/#{event}", {}
        last_response.should_not be_successful
      end

      it 'returns a 403 status code' do
        post "/track/#{event}", {}
        last_response.status.should == 403
      end

      it 'responds with "forbidden"' do
        post "/track/#{event}", {}
        last_response.body.should =~ /forbidden/i
      end
    end

    context 'with a new event' do
      it 'succeeds' do
        post "/track/#{event}", default_params
        last_response.should be_successful
      end

      it 'responds with "OK"' do
        post "/track/#{event}", default_params
        last_response.body.should =~ /ok/i
      end

      it "increments a key with minute-granularity in Redis" do
        expect { post "/track/#{event}", default_params }.to change {
          Duckweed.redis.get("duckweed:#{event}:minutes:#{@now.to_i / 60}")
        }.from(nil).to(1)
      end

      it "increments a key with hour-granularity in Redis" do
        expect { post "/track/#{event}", default_params }.to change {
          Duckweed.redis.get("duckweed:#{event}:hours:#{@now.to_i / 3600}")
        }.from(nil).to(1)
      end

      it "increments a key with day-granularity in Redis" do
        expect { post "/track/#{event}", default_params }.to change {
          Duckweed.redis.get("duckweed:#{event}:days:#{@now.to_i / 86400}")
        }.from(nil).to(1)
      end
    end

    context 'with a previously-seen event' do
      before do
        post "/track/#{event}", default_params
      end

      it 'succeeds' do
        post "/track/#{event}", default_params
        last_response.should be_successful
      end

      it 'responds with "OK"' do
        post "/track/#{event}", default_params
        last_response.body.should =~ /ok/i
      end

      it "increments a key with minute-granularity in Redis" do
        expect { post "/track/#{event}", default_params }.to change {
          Duckweed.redis.get("duckweed:#{event}:minutes:#{@now.to_i / 60}")
        }.by(1)
      end

      it "increments a key with hour-granularity in Redis" do
        expect { post "/track/#{event}", default_params }.to change {
          Duckweed.redis.get("duckweed:#{event}:hours:#{@now.to_i / 3600}")
        }.by(1)
      end

      it "increments a key with day-granularity in Redis" do
        expect { post "/track/#{event}", default_params }.to change {
          Duckweed.redis.get("duckweed:#{event}:days:#{@now.to_i / 86400}")
        }.by(1)
      end
    end

    context 'with an explicit timestamp param' do
      before do
        # simulate a big delay in a Beanstalk queue
        @timestamp = @now.to_i - 600_000
      end

      it 'uses the timestamp rather than Time.now' do
        Duckweed.redis.should_receive(:incr).
          with("duckweed:#{event}:minutes:#{@timestamp / 60}")
        Duckweed.redis.should_receive(:incr).
          with("duckweed:#{event}:hours:#{@timestamp / 3600}")
        Duckweed.redis.should_receive(:incr).
          with("duckweed:#{event}:days:#{@timestamp / 86400}")
        post "/track/#{event}", default_params.merge(:timestamp => @timestamp)
      end
    end

    it 'expires minute-granularity data after a day' do
      Duckweed.redis.stub!(:expire)
      Duckweed.redis.should_receive(:expire).
        with("duckweed:#{event}:minutes:#{@now.to_i / 60}", 86400)
      post "/track/#{event}", default_params
    end

    it 'expires hour-granularity data after a week' do
      Duckweed.redis.stub!(:expire)
      Duckweed.redis.should_receive(:expire).
        with("duckweed:#{event}:hours:#{@now.to_i / 3600}", 86400 * 7)
      post "/track/#{event}", default_params
    end

    it 'expires day-granularity data after a year' do
      Duckweed.redis.stub!(:expire)
      Duckweed.redis.should_receive(:expire).
        with("duckweed:#{event}:days:#{@now.to_i / 86400}", 86400 * 365)
      post "/track/#{event}", default_params
    end
  end

  describe 'GET /count/:event' do
    it 'succeeds' do
      get "/count/#{event}"
      last_response.should be_successful
    end

    context 'with no events recorded' do
      it 'responds with 0' do
        get "/count/#{event}"
        last_response.body.should == '0'
      end
    end

    context 'with multiple events recorded' do
      before do
        3.times { post "/track/#{event}", default_params }
      end

      it 'responds with the count' do
        get "/count/#{event}"
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the last hour' do
        Time.stub!(:now).and_return(@now - 5400) # 90 minutes ago
        3.times { post "/track/#{event}", default_params }
        get "/count/#{event}"
        last_response.body.should == '3'
      end
    end
  end

  describe 'GET /count/:event/:granularity/:quantity' do
    before do
      3.times { post "/track/#{event}", default_params }
    end

    context 'with an unknown granularity' do
      it 'fails' do
        get "/count/#{event}/femtoseconds/10"
        last_response.should_not be_successful
      end

      it 'returns a 400 status code' do
        get "/count/#{event}/femtoseconds/10"
        last_response.status.should == 400
      end

      it 'responds with "Bad Request"' do
        get "/count/#{event}/femtoseconds/10"
        last_response.body.should =~ /bad request/i
      end
    end

    context 'with minutes granularity' do
      it 'succeeds' do
        get "/count/#{event}/minutes/5"
        last_response.should be_successful
      end

      it 'responds with the count' do
        get "/count/#{event}/minutes/5"
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the specified interval' do
        Time.stub!(:now).and_return(@now - 600) # 10 minutes ago
        3.times { post "/track/#{event}", default_params }
        get "/count/#{event}/minutes/5"
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        Time.stub!(:now).and_return(@now - 600) # 10 minutes ago
        post "/track/#{event}", default_params
        get "/count/#{event}/minutes/5?timestamp=#{(@now - 480).to_i}" # offset starting 8 minutes ago
        last_response.body.should == '1'
      end

      context 'with a quantity that exceeds the expiry limit' do
        it 'fails' do
          get "/count/#{event}/minutes/1500" # 1500 minutes = 1 day, 1 hour
          last_response.should_not be_successful
        end

        it 'returns a 413 status code' do
          get "/count/#{event}/minutes/1500"
          last_response.status.should == 413
        end

        it 'responds with "Request Entity Too Large"' do
          get "/count/#{event}/minutes/1500"
          last_response.body.should =~ /request entity too large/i
        end
      end
    end

    context 'with hours granularity' do
      it 'succeeds' do
        get "/count/#{event}/hours/5"
        last_response.should be_successful
      end

      it 'responds with the count' do
        get "/count/#{event}/hours/5"
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the specified interval' do
        Time.stub!(:now).and_return(@now - 21600) # 6 hours ago
        3.times { post "/track/#{event}", default_params }
        get "/count/#{event}/hours/5"
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        Time.stub!(:now).and_return(@now - 36000) # 10 hours ago
        post "/track/#{event}", default_params
        get "/count/#{event}/hours/5?timestamp=#{(@now - 28800).to_i}" # offset starting 8 hours ago
        last_response.body.should == '1'
      end

      context 'with a quantity that exceeds the expiry limit' do
        it 'fails' do
          get "/count/#{event}/hours/192" # 192 hours = 8 days
          last_response.should_not be_successful
        end

        it 'returns a 413 status code' do
          get "/count/#{event}/hours/192"
          last_response.status.should == 413
        end

        it 'responds with "Request Entity Too Large"' do
          get "/count/#{event}/hours/192"
          last_response.body.should =~ /request entity too large/i
        end
      end
    end

    context 'with days granularity' do
      it 'succeeds' do
        get "/count/#{event}/days/5"
        last_response.should be_successful
      end

      it 'responds with the count' do
        get "/count/#{event}/days/5"
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the specified interval' do
        Time.stub!(:now).and_return(@now - 864000) # 10 days ago
        3.times { post "/track/#{event}", default_params }
        get "/count/#{event}/days/5"
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        Time.stub!(:now).and_return(@now - 864000) # 10 days ago
        post "/track/#{event}", default_params
        get "/count/#{event}/days/5?timestamp=#{(@now - 691200).to_i}" # offset starting 8 days ago
        last_response.body.should == '1'
      end

      context 'with a quantity that exceeds the expiry limit' do
        it 'fails' do
          get "/count/#{event}/days/400" # 400 days = 1 year, 35 days
          last_response.should_not be_successful
        end

        it 'returns a 413 status code' do
          get "/count/#{event}/days/400"
          last_response.status.should == 413
        end

        it 'responds with "Request Entity Too Large"' do
          get "/count/#{event}/days/400"
          last_response.body.should =~ /request entity too large/i
        end
      end
    end
  end

  describe 'GET /histogram/:event/:granularity/:quantity' do
    context 'without an authentication token' do
      it 'fails' do
        get "/histogram/#{event}/minutes/60"
        last_response.should_not be_successful
      end

      it 'returns a 403 response code' do
        get "/histogram/#{event}/minutes/60"
        last_response.status.should == 403
      end

      it 'responds with "Forbidden"' do
        get "/histogram/#{event}/minutes/60"
        last_response.body.should =~ /forbidden/i
      end
    end
  end
end
