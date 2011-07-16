require 'spec_helper'

describe Duckweed::App do
  let(:event) { 'test-event-47781' }
  let(:app) { described_class }
  let(:default_params) { { :auth_token => Duckweed::Token.authorize('abcd') } }

  before { freeze_time }

  describe 'GET /count/:event' do
    it_should_behave_like 'pages needing readonly auth' do
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
        event_happened(:times => 3, :at => @now - MINUTE)
      end

      it 'responds with the count' do
        get "/count/#{event}", default_params
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the last hour' do
        event_happened(:times => 3, :at => @now - 90 * MINUTE)
        get "/count/#{event}", default_params
        last_response.body.should == '3'
      end

    end

    context 'ignoring the last (incomplete) bucket' do

      it 'does not return the current (partial) bucket unless asked' do

        event_happened(:at => @now - HOUR)                # just over an hour ago
        event_happened(:at => @now - HOUR/2, :times => 2) # in the middle of the hour
        event_happened(:at => @now,          :times => 4) # within the current (partial) bucket

        get "/count/#{event}", default_params

        last_response.body.should == '3'
      end
    end


  end

  describe 'GET /count/:event/:granularity/:quantity' do
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
      before do
        event_happened(:times => 3, :at => @now - MINUTE)
      end

      it 'succeeds' do
        get "/count/#{event}/minutes/5", default_params
        last_response.should be_successful
      end

      it 'responds with the count' do
        get "/count/#{event}/minutes/5", default_params
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the specified interval' do
        event_happened(:times => 3, :at => @now - (10 * MINUTE))
        get "/count/#{event}/minutes/5", default_params
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        event_happened(:at => @now - (10 * MINUTE))
        get "/count/#{event}/minutes/5",
            default_params.merge(:timestamp => (@now - (8 * MINUTE)).to_i)
        last_response.body.should == '1'
      end

      context 'with a quantity that exceeds the expiry limit' do
        it 'fails' do
          get "/count/#{event}/minutes/3000", default_params # 2 day, 2 hours
          last_response.should_not be_successful
        end

        it 'returns a 413 status code' do
          get "/count/#{event}/minutes/3000", default_params
          last_response.status.should == 413
        end

        it 'responds with "Request Entity Too Large"' do
          get "/count/#{event}/minutes/3000", default_params
          last_response.body.should =~ /request entity too large/i
        end
      end

      context 'when given an offset' do
        it 'shows the correct event data' do
          event_happened(:at => @now - (5  * MINUTE), :times => 2)
          event_happened(:at => @now - (10 * MINUTE), :times => 4)
          event_happened(:at => @now - (15 * MINUTE), :times => 8)

          get "count/#{event}/minutes/10", default_params.merge(:offset => 5)

          last_response.body.should == '6' # should get 5-min and 10-min events only
        end
      end

    end

    context 'with hours granularity' do
      before do
        event_happened(:times => 3, :at => @now - HOUR)
      end

      it 'succeeds' do
        get "/count/#{event}/hours/5", default_params
        last_response.should be_successful
      end

      it 'responds with the count' do
        get "/count/#{event}/hours/5", default_params
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the specified interval' do
        event_happened(:times => 3, :at => @now - (6 * HOUR))
        get "/count/#{event}/hours/5", default_params
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        event_happened(:at => @now - (10 * HOUR))
        get "/count/#{event}/hours/5",
          default_params.merge(:timestamp => (@now - (8 * HOUR)).to_i)
        last_response.body.should == '1'
      end

      context 'with a quantity that exceeds the expiry limit' do
        it 'fails' do
          get "/count/#{event}/hours/768", default_params # 768 hours = 32 days
          last_response.should_not be_successful
        end

        it 'returns a 413 status code' do
          get "/count/#{event}/hours/768", default_params
          last_response.status.should == 413
        end

        it 'responds with "Request Entity Too Large"' do
          get "/count/#{event}/hours/768", default_params
          last_response.body.should =~ /request entity too large/i
        end
      end

      context 'when given an offset' do
        it 'shows the correct event data' do
          event_happened(:at => @now - (5  * HOUR), :times => 3)
          event_happened(:at => @now - (10 * HOUR), :times => 5)
          event_happened(:at => @now - (15 * HOUR), :times => 7)

          get "count/#{event}/hours/10", default_params.merge(:offset => 5)

          last_response.body.should == '8' # should get 5-hr and 10-hr events only
        end
      end
    end

    context 'with days granularity' do
      before do
        event_happened(:times => 3, :at => @now - DAY)
      end

      it 'succeeds' do
        get "/count/#{event}/days/5", default_params
        last_response.should be_successful
      end

      it 'responds with the count' do
        get "/count/#{event}/days/5", default_params
        last_response.body.should == '3'
      end

      it 'counts only events tracked in the specified interval' do
        event_happened(:times => 3, :at => @now - (10 * DAY))
        get "/count/#{event}/days/5", default_params
        last_response.body.should == '3'
      end

      it 'uses the optional timestamp param as an offset' do
        event_happened(:at => @now - (10 * DAY))
        get "/count/#{event}/days/5",
          default_params.merge(:timestamp => (@now - (8 * DAY)).to_i)
        last_response.body.should == '1'
      end

      context 'with a quantity that exceeds the expiry limit' do
        it 'fails' do
          get "/count/#{event}/days/3200", default_params # 3200 days = 8 years, 280 days
          last_response.should_not be_successful
        end

        it 'returns a 413 status code' do
          get "/count/#{event}/days/3200", default_params
          last_response.status.should == 413
        end

        it 'responds with "Request Entity Too Large"' do
          get "/count/#{event}/days/3200", default_params
          last_response.body.should =~ /request entity too large/i
        end
      end
      context 'when given an offset' do
        it 'shows the correct event data' do
          event_happened(:at => @now - (5  * DAY), :times => 1)
          event_happened(:at => @now - (10 * DAY), :times => 2)
          event_happened(:at => @now - (15 * DAY), :times => 4)

          get "count/#{event}/days/10", default_params.merge(:offset => 5)

          last_response.body.should == '3' # should get 5-day and 10-day events only
        end
      end
    end
  end
end
