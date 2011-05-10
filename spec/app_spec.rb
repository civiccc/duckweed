require "spec_helper"

describe Duckweed::App do
  let(:event) { 'test-event-47781' }
  let(:app) { described_class }
  let(:default_params) { { :auth_token => Duckweed::AUTH_TOKENS.first } }

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
        }.from(nil).to('1')
      end

      it "increments a key with hour-granularity in Redis" do
        expect { post "/track/#{event}", default_params }.to change {
          Duckweed.redis.get("duckweed:#{event}:hours:#{@now.to_i / 3600}")
        }.from(nil).to('1')
      end

      it "increments a key with day-granularity in Redis" do
        expect { post "/track/#{event}", default_params }.to change {
          Duckweed.redis.get("duckweed:#{event}:days:#{@now.to_i / 86400}")
        }.from(nil).to('1')
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
          Duckweed.redis.get("duckweed:#{event}:minutes:#{@now.to_i / 60}").to_i
        }.by(1)
      end

      it "increments a key with hour-granularity in Redis" do
        expect { post "/track/#{event}", default_params }.to change {
          Duckweed.redis.get("duckweed:#{event}:hours:#{@now.to_i / 3600}").to_i
        }.by(1)
      end

      it "increments a key with day-granularity in Redis" do
        expect { post "/track/#{event}", default_params }.to change {
          Duckweed.redis.get("duckweed:#{event}:days:#{@now.to_i / 86400}").to_i
        }.by(1)
      end
    end

    context 'with an explicit timestamp param' do
      before do
        # simulate a big delay in a Beanstalk queue
        @timestamp = @now.to_i - 6000
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

      it "does not make fine-grained records for long-ago events" do
        long_ago = Time.now.to_i - (86400*30)  # 30 days
        post "/track/#{event}", default_params.merge(:timestamp => long_ago)

        # NB: the redis mock gets cleared before every example
        Duckweed.redis.keys('*').should ==
          ["duckweed:#{event}:days:#{long_ago / 86400}"]
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
        event_happened(:times => 3)
      end

      it 'responds with the count' do
        get "/count/#{event}"
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the last hour' do
        Time.stub!(:now).and_return(@now - 5400) # 90 minutes ago
        event_happened(:times => 3)
        get "/count/#{event}"
        last_response.body.should == '3'
      end
    end
  end

  describe 'GET /count/:event/:granularity/:quantity' do
    before do
      event_happened(:times => 3)
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
        event_happened(:times => 3)
        get "/count/#{event}/minutes/5"
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        Time.stub!(:now).and_return(@now - 600) # 10 minutes ago
        event_happened
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
        event_happened(:times => 3)
        get "/count/#{event}/hours/5"
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        Time.stub!(:now).and_return(@now - 36000) # 10 hours ago
        event_happened
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
        event_happened(:times => 3)
        get "/count/#{event}/days/5"
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        Time.stub!(:now).and_return(@now - 864000) # 10 days ago
        event_happened
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

    context 'with an authentication token' do
      before do
        authorize Duckweed::AUTH_TOKENS.first, ''
      end

      context "when we have no data in some buckets" do
        before do
          event_happened(:times => 3, :at => Time.now)
          event_happened(:times => 5, :at => Time.now - 600) # 10 minutes ago

          get "/histogram/#{event}/minutes/60"
        end

        it "does not crash" do
          last_response.should be_successful
        end

        it "doesn't leak nils (Geckoboard hates nils)" do
          JSON[last_response.body]["item"].each do |item|
            item.should_not be_nil
          end
        end

        it "sums to the correct value" do
          JSON[last_response.body]["item"].inject(0, &:+).should == 8
        end
      end

      context 'with an unknown granularity' do
        it 'fails' do
          get "/histogram/#{event}/femtoseconds/10"
          last_response.should_not be_successful
        end

        it 'returns a 400 status code' do
          get "/histogram/#{event}/femtoseconds/10"
          last_response.status.should == 400
        end

        it 'responds with "Bad Request"' do
          get "/histogram/#{event}/femtoseconds/10"
          last_response.body.should =~ /bad request/i
        end
      end

      context 'with minutes granularity' do
        before do
          event_happened(:times => 3, :at => Time.now - 120) # 2 minutes ago
          event_happened(:times => 5, :at => Time.now - 60)  # 1 minute ago
          event_happened(:times => 2, :at => Time.now)
        end

        context 'with a quantity that exceeds the expiry limit' do
          it 'fails' do
            get "/histogram/#{event}/minutes/1500" # 1500 minutes = 1 day, 1 hour
            last_response.should_not be_successful
          end

          it 'returns a 413 status code' do
            get "/histogram/#{event}/minutes/1500" # 1500 minutes = 1 day, 1 hour
            last_response.status.should == 413
          end

          it 'responds with "Request Entity Too Large"' do
            get "/histogram/#{event}/minutes/1500" # 1500 minutes = 1 day, 1 hour
            last_response.body.should =~ /request entity too large/i
          end
        end

        it 'returns event frequencies in chronological order' do
          get "/histogram/#{event}/minutes/4"
          JSON[last_response.body]['item'].should == [0, 3, 5, 2]
        end

        it 'returns 0 when there are no events' do
          get "/histogram/untracked/minutes/4"
          JSON[last_response.body]['item'].should == [0, 0, 0, 0]
        end

        it 'returns the min, mid and max values for the y-axis' do
          get "/histogram/#{event}/minutes/4"
          JSON[last_response.body]['settings']['axisy'].should == [0, 2.5, 5]
        end
      end

      context 'with hours granularity' do
        before do
          event_happened(:times => 6, :at => Time.now - 7200) # 2 hours ago
          event_happened(:times => 2, :at => Time.now - 3600) # 1 hour ago
          event_happened(:times => 3, :at => Time.now)
        end

        context 'with a quantity that exceeds the expiry limit' do
          it 'fails' do
            get "/histogram/#{event}/hours/192" # 192 hours = 8 days
            last_response.should_not be_successful
          end

          it 'returns a 413 status code' do
            get "/histogram/#{event}/hours/192"
            last_response.status.should == 413
          end

          it 'responds with "Request Entity Too Large"' do
            get "/histogram/#{event}/hours/192"
            last_response.body.should =~ /request entity too large/i
          end
        end

        it 'returns event frequencies in chronological order' do
          get "/histogram/#{event}/hours/4"
          JSON[last_response.body]['item'].should == [0, 6, 2, 3]
        end

        it 'returns 0 when there are no events' do
          get "/histogram/untracked/hours/4"
          JSON[last_response.body]['item'].should == [0, 0, 0, 0]
        end

        it 'returns the min, mid and max values for the y-axis' do
          get "/histogram/#{event}/hours/4"
          JSON[last_response.body]['settings']['axisy'].should == [0, 3.0, 6]
        end
      end

      context 'with days granularity' do
        before do
          event_happened(:times => 2, :at => Time.now - 172800) # 2 days ago
          event_happened(:times => 4, :at => Time.now - 86400)  # 1 day ago
          event_happened(:times => 5, :at => Time.now)
        end

        context 'with a quantity that exceeds the expiry limit' do
          it 'fails' do
            get "/histogram/#{event}/days/400" # 400 days = 1 year, 35 days
            last_response.should_not be_successful
          end

          it 'returns a 413 status code' do
            get "/histogram/#{event}/days/400"
            last_response.status.should == 413
          end

          it 'responds with "Request Entity Too Large"' do
            get "/histogram/#{event}/days/400"
            last_response.body.should =~ /request entity too large/i
          end
        end

        it 'returns event frequencies in chronological order' do
          get "/histogram/#{event}/days/4"
          JSON[last_response.body]['item'].should == [0, 2, 4, 5]
        end

        it 'returns 0 when there are no events' do
          get "/histogram/untracked/days/4"
          JSON[last_response.body]['item'].should == [0, 0, 0, 0]
        end

        it 'returns the min, mid and max values for the y-axis' do
          get "/histogram/#{event}/days/4"
          JSON[last_response.body]['settings']['axisy'].should == [0, 2.5, 5]
        end
      end
    end
  end
end
