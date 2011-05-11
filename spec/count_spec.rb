require "spec_helper"

describe Duckweed::App do
  let(:event) { 'test-event-47781' }
  let(:app) { described_class }
  let(:default_params) { { :auth_token => Duckweed::AUTH_TOKENS.first } }

  before { freeze_time }

  describe 'GET /count/:event' do
    it_should_behave_like 'pages with auth' do
      def do_request
        get "/count/#{event}", {}
      end
    end

    it 'succeeds' do
      get "/count/#{event}", default_params
      last_response.should be_successful
    end

    context 'with no events recorded' do
      it 'responds with 0' do
        get "/count/#{event}", default_params
        last_response.body.should == '0'
      end
    end

    context 'with multiple events recorded' do
      before do
        event_happened(:times => 3)
      end

      it 'responds with the count' do
        get "/count/#{event}", default_params
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the last hour' do
        Time.stub!(:now).and_return(@now - 5400) # 90 minutes ago
        event_happened(:times => 3)
        get "/count/#{event}", default_params
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
        get "/count/#{event}/femtoseconds/10", default_params
        last_response.should_not be_successful
      end

      it 'returns a 400 status code' do
        get "/count/#{event}/femtoseconds/10", default_params
        last_response.status.should == 400
      end

      it 'responds with "Bad Request"' do
        get "/count/#{event}/femtoseconds/10", default_params
        last_response.body.should =~ /bad request/i
      end
    end

    context 'with minutes granularity' do
      it 'succeeds' do
        get "/count/#{event}/minutes/5", default_params
        last_response.should be_successful
      end

      it 'responds with the count' do
        get "/count/#{event}/minutes/5", default_params
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the specified interval' do
        Time.stub!(:now).and_return(@now - 600) # 10 minutes ago
        event_happened(:times => 3)
        get "/count/#{event}/minutes/5", default_params
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        Time.stub!(:now).and_return(@now - 600) # 10 minutes ago
        event_happened
        get "/count/#{event}/minutes/5?timestamp=#{(@now - 480).to_i}", default_params # 8 minutes ago
        last_response.body.should == '1'
      end

      context 'with a quantity that exceeds the expiry limit' do
        it 'fails' do
          get "/count/#{event}/minutes/1500", default_params # 1 day, 1 hour
          last_response.should_not be_successful
        end

        it 'returns a 413 status code' do
          get "/count/#{event}/minutes/1500", default_params
          last_response.status.should == 413
        end

        it 'responds with "Request Entity Too Large"' do
          get "/count/#{event}/minutes/1500", default_params
          last_response.body.should =~ /request entity too large/i
        end
      end
    end

    context 'with hours granularity' do
      it 'succeeds' do
        get "/count/#{event}/hours/5", default_params
        last_response.should be_successful
      end

      it 'responds with the count' do
        get "/count/#{event}/hours/5", default_params
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the specified interval' do
        Time.stub!(:now).and_return(@now - 21600) # 6 hours ago
        event_happened(:times => 3)
        get "/count/#{event}/hours/5", default_params
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        Time.stub!(:now).and_return(@now - 36000) # 10 hours ago
        event_happened
        get "/count/#{event}/hours/5?timestamp=#{(@now - 28800).to_i}", default_params # 8 hours ago
        last_response.body.should == '1'
      end

      context 'with a quantity that exceeds the expiry limit' do
        it 'fails' do
          get "/count/#{event}/hours/192", default_params # 192 hours = 8 days
          last_response.should_not be_successful
        end

        it 'returns a 413 status code' do
          get "/count/#{event}/hours/192", default_params
          last_response.status.should == 413
        end

        it 'responds with "Request Entity Too Large"' do
          get "/count/#{event}/hours/192", default_params
          last_response.body.should =~ /request entity too large/i
        end
      end
    end

    context 'with days granularity' do
      it 'succeeds' do
        get "/count/#{event}/days/5", default_params
        last_response.should be_successful
      end

      it 'responds with the count' do
        get "/count/#{event}/days/5", default_params
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the specified interval' do
        Time.stub!(:now).and_return(@now - 864000) # 10 days ago
        event_happened(:times => 3)
        get "/count/#{event}/days/5", default_params
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        Time.stub!(:now).and_return(@now - 864000) # 10 days ago
        event_happened
        get "/count/#{event}/days/5?timestamp=#{(@now - 691200).to_i}", default_params # 8 days ago
        last_response.body.should == '1'
      end

      context 'with a quantity that exceeds the expiry limit' do
        it 'fails' do
          get "/count/#{event}/days/400", default_params # 400 days = 1 year, 35 days
          last_response.should_not be_successful
        end

        it 'returns a 413 status code' do
          get "/count/#{event}/days/400", default_params
          last_response.status.should == 413
        end

        it 'responds with "Request Entity Too Large"' do
          get "/count/#{event}/days/400", default_params
          last_response.body.should =~ /request entity too large/i
        end
      end
    end
  end
end
