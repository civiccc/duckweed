require 'spec_helper'

describe Duckweed::App do
  let(:event) { 'test-event-47781' }
  let(:app) { described_class }
  let(:default_params) { { :auth_token => Duckweed::Token.authorize('foo') } }

  before { freeze_time }

  describe 'GET /histogram/:event/:granularity/:quantity' do
    it_should_behave_like 'pages needing readonly auth' do
      def do_request
        get "/histogram/#{event}/minutes/60"
      end
    end

    context 'with an authentication token' do
      before do
        authorize Duckweed::Token.authorize('bar'), ''
      end

      context "when we have no data in some buckets" do
        before do
          event_happened(:times => 5, :at => Time.now - (10 * MINUTE))
          event_happened(:times => 3, :at => Time.now - MINUTE)
          event_happened(:times => 7, :at => Time.now)

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
          event_happened(:times => 3,  :at => Time.now - (3 * MINUTE))
          event_happened(:times => 5,  :at => Time.now - (2 * MINUTE))
          event_happened(:times => 2,  :at => Time.now -      MINUTE)
          event_happened(:times => 11, :at => Time.now)       # should not get counted
        end

        context 'with a quantity that exceeds the expiry limit' do
          it 'fails' do
            get "/histogram/#{event}/minutes/3000" # 3000 minutes = 2 days, 2 hours
            last_response.should_not be_successful
          end

          it 'returns a 413 status code' do
            get "/histogram/#{event}/minutes/3000"
            last_response.status.should == 413
          end

          it 'responds with "Request Entity Too Large"' do
            get "/histogram/#{event}/minutes/3000"
            last_response.body.should =~ /request entity too large/i
          end
        end

        it "gives you a full day's worth of data" do
          get "/histogram/#{event}/minutes/#{60*24}"
          last_response.should be_successful
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

        it 'puts the mean in the mid-value for the y axis' do
          get "/histogram/#{event}/minutes/3"
          JSON[last_response.body]['settings']['axisy'].should == [2, 3.5, 5]
        end

        it 'correctly honors the optional offset param' do
          get "/histogram/#{event}/minutes/3", {:offset => 2}
          JSON[last_response.body]['item'].should == [0, 3, 5]
        end

      end

      context 'with hours granularity' do
        before do
          event_happened(:times => 6,   :at => Time.now - (3 * HOUR))
          event_happened(:times => 2,   :at => Time.now - (2 * HOUR))
          event_happened(:times => 3,   :at => Time.now -      HOUR)
          event_happened(:times => 127, :at => Time.now)           # should not get counted
        end

        context 'with a quantity that exceeds the expiry limit' do
          it 'fails' do
            get "/histogram/#{event}/hours/768" # 768 hours = 32 days
            last_response.should_not be_successful
          end

          it 'returns a 413 status code' do
            get "/histogram/#{event}/hours/768"
            last_response.status.should == 413
          end

          it 'responds with "Request Entity Too Large"' do
            get "/histogram/#{event}/hours/768"
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

        it 'correctly honors the optional offset param' do
          get "/histogram/#{event}/hours/3", {:offset => 2}
          JSON[last_response.body]['item'].should == [0, 6, 2]
        end

      end

      context 'with days granularity' do
        before do
          event_happened(:times => 2, :at => Time.now - (3 * DAY))
          event_happened(:times => 4, :at => Time.now - (2 * DAY))
          event_happened(:times => 5, :at => Time.now -      DAY)
          event_happened(:times => 9, :at => Time.now)              # should not get counted
        end

        context 'with a quantity that exceeds the expiry limit' do
          it 'fails' do
            get "/histogram/#{event}/days/3200" # 3200 days = 8 years, 280 days
            last_response.should_not be_successful
          end

          it 'returns a 413 status code' do
            get "/histogram/#{event}/days/3200"
            last_response.status.should == 413
          end

          it 'responds with "Request Entity Too Large"' do
            get "/histogram/#{event}/days/3200"
            last_response.body.should =~ /request entity too large/i
          end
        end

        context "with a quantity+offset that exceeds the limit" do
          it "returns a 413 status code" do
            get "/histogram/#{event}/hours/768?offset=100"
            last_response.status.should == 413
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

        it 'correctly honors the optional offset param' do
          get "/histogram/#{event}/days/3", {:offset => 2}
          JSON[last_response.body]['item'].should == [0, 2, 4]
        end
      end
    end
  end
end
