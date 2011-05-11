require 'spec_helper'

describe Duckweed::App do
  let(:event) { 'test-event-47781' }
  let(:app) { described_class }
  let(:default_params) { { :auth_token => Duckweed::AUTH_TOKENS.first } }

  before { freeze_time }

  describe 'GET /histogram/:event/:granularity/:quantity' do
    it_should_behave_like 'pages with auth' do
      def do_request
        get "/histogram/#{event}/minutes/60"
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
