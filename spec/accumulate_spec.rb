require 'spec_helper'

describe Duckweed::App do
  let(:event) { 'test-event-47781' }
  let(:app) { described_class }
  let(:default_params) { { :auth_token => Duckweed::AUTH_TOKENS.first } }

  before { freeze_time }

  describe 'GET /accumulate/:event/:granularity/:quantity' do
    it_should_behave_like 'pages with auth' do
      def do_request
        get "/accumulate/#{event}/minutes/60"
      end
    end

    context 'with an authentication token' do
      before do
        authorize Duckweed::AUTH_TOKENS.first, ''
      end

      context "when we have no data in some buckets" do
        before do
          event_happened(:times => 5, :at => Time.now - (10 * MINUTE))
          event_happened(:times => 3, :at => Time.now - MINUTE)
          event_happened(:times => 7, :at => Time.now)

          get "/accumulate/#{event}/minutes/60"
        end

        it "does not crash" do
          last_response.should be_successful
        end

        it "doesn't leak nils (Geckoboard hates nils)" do
          JSON[last_response.body]["item"].each do |item|
            item.should_not be_nil
          end
        end

      end

      context 'with an unknown granularity' do
        it 'fails' do
          get "/accumulate/#{event}/femtoseconds/10"
          last_response.should_not be_successful
        end

        it 'returns a 400 status code' do
          get "/accumulate/#{event}/femtoseconds/10"
          last_response.status.should == 400
        end

        it 'responds with "Bad Request"' do
          get "/accumulate/#{event}/femtoseconds/10"
          last_response.body.should =~ /bad request/i
        end
      end

      context 'with minutes granularity' do
        before do
          event_happened(:times => 1,   :at => Time.now - (23 * HOUR))
          event_happened(:times => 2,   :at => Time.now - (2  * HOUR))
          event_happened(:times => 8,   :at => Time.now - (1  * HOUR))
          event_happened(:times => 12,  :at => Time.now - (3  * MINUTE))
          event_happened(:times => 21,  :at => Time.now - (2  * MINUTE))
          event_happened(:times => 24,  :at => Time.now -       MINUTE)
          event_happened(:times => 261, :at => Time.now)       # should not get counted
        end

        context 'with a quantity that exceeds the expiry limit' do
          it 'fails' do
            get "/accumulate/#{event}/minutes/3000" # 3000 minutes = 2 days, 2 hours
            last_response.should_not be_successful
          end

          it 'returns a 413 status code' do
            get "/accumulate/#{event}/minutes/3000" # 3000 minutes = 2 days, 2 hours
            last_response.status.should == 413
          end

          it 'responds with "Request Entity Too Large"' do
            get "/accumulate/#{event}/minutes/3000" # 3000 minutes = 2 days, 2 hours
            last_response.body.should =~ /request entity too large/i
          end
        end

        it 'returns event totals in chronological order' do
          get "/accumulate/#{event}/minutes/4"
          JSON[last_response.body]['item'].should == [11, 23, 44, 68]
        end

        it 'returns 0 when there are no events' do
          get "/accumulate/untracked/minutes/4"
          JSON[last_response.body]['item'].should == [0, 0, 0, 0]
        end

        it 'returns the min, mid and max values for the y-axis' do
          get "/accumulate/#{event}/minutes/4"
          JSON[last_response.body]['settings']['axisy'].should == [11, 39.5, 68]
        end

        it 'correctly honors the optional offset param' do
          get "/accumulate/#{event}/minutes/3", {:offset => 2}
          JSON[last_response.body]['item'].should == [11, 23, 44]
        end

      end

      context 'with hours granularity' do
        before do
          event_happened(:times => 11,  :at => Time.now - (3 * HOUR))
          event_happened(:times => 7,   :at => Time.now - (2 * HOUR))
          event_happened(:times => 5,   :at => Time.now -      HOUR)
          event_happened(:times => 127, :at => Time.now)           # should not get counted
        end

        context 'with a quantity that exceeds the expiry limit' do
          it 'fails' do
            get "/accumulate/#{event}/hours/768" # 384 hours = 32 days
            last_response.should_not be_successful
          end

          it 'returns a 413 status code' do
            get "/accumulate/#{event}/hours/768"
            last_response.status.should == 413
          end

          it 'responds with "Request Entity Too Large"' do
            get "/accumulate/#{event}/hours/768"
            last_response.body.should =~ /request entity too large/i
          end
        end

        it 'returns event frequencies in chronological order' do
          get "/accumulate/#{event}/hours/4"
          JSON[last_response.body]['item'].should == [0, 11, 18, 23]
        end

        it 'returns 0 when there are no events' do
          get "/accumulate/untracked/hours/4"
          JSON[last_response.body]['item'].should == [0, 0, 0, 0]
        end

        it 'returns the min, mid and max values for the y-axis' do
          get "/accumulate/#{event}/hours/4"
          JSON[last_response.body]['settings']['axisy'].should == [0, 11.5, 23]
        end

        it 'correctly honors the optional offset param' do
          get "/accumulate/#{event}/hours/3", {:offset => 2}
          JSON[last_response.body]['item'].should == [0, 11, 18]
        end

      end

      context 'with days granularity' do
        before do
          event_happened(:times => 5,  :at => Time.now - (3 * DAY))
          event_happened(:times => 7,  :at => Time.now - (2 * DAY))
          event_happened(:times => 3,  :at => Time.now -      DAY)
          event_happened(:times => 11, :at => Time.now)              # should not get counted
        end

        context 'with a quantity that exceeds the expiry limit' do
          it 'fails' do
            get "/accumulate/#{event}/days/3200" # 1600 days = 8 years, 280 days
            last_response.should_not be_successful
          end

          it 'returns a 413 status code' do
            get "/accumulate/#{event}/days/3200"
            last_response.status.should == 413
          end

          it 'responds with "Request Entity Too Large"' do
            get "/accumulate/#{event}/days/3200"
            last_response.body.should =~ /request entity too large/i
          end
        end

        it 'returns event frequencies in chronological order' do
          get "/accumulate/#{event}/days/4"
          JSON[last_response.body]['item'].should == [0, 5, 12, 15]
        end

        it 'returns 0 when there are no events' do
          get "/accumulate/untracked/days/4"
          JSON[last_response.body]['item'].should == [0, 0, 0, 0]
        end

        it 'returns the min, mid and max values for the y-axis' do
          get "/accumulate/#{event}/days/4"
          JSON[last_response.body]['settings']['axisy'].should == [0, 7.5, 15]
        end

        it 'correctly honors the optional offset param' do
          get "/accumulate/#{event}/days/3", {:offset => 2}
          JSON[last_response.body]['item'].should == [0, 5, 12]
        end
      end
    end
  end
end
