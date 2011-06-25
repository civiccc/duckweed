require 'spec_helper'

describe Duckweed::App do
  let(:event) { 'test-event-28486' }
  let(:event2) { 'test-event2-71170!' }
  let(:app) { described_class }
  let(:default_params) { { :auth_token => Duckweed::AUTH_TOKENS.first } }

  before { freeze_time }

  describe 'GET /multicount?e[]=event1' do
    it_should_behave_like 'pages with auth' do
      def do_request
        post "/multicount", {'events' => [event]}
      end
    end

    context 'with an authentication token' do
      def post_multicount(events=[], params={})
        post "/multicount", params.merge('events' => events.flatten)
        last_response.should be_successful
      end

      before do
        authorize Duckweed::AUTH_TOKENS.first, ''
      end

      it "returns data for the events in the right order" do
        1.upto(5) do |i|
          event_happened(
            :event => "event#{i}",
            :times => i,
            :at => Time.now - MINUTE)
        end

        post_multicount(%w[event1 event2 event3 event4 event5])

        JSON[last_response.body]["event1"].should == 1
        JSON[last_response.body]["event2"].should == 2
        JSON[last_response.body]["event3"].should == 3
        JSON[last_response.body]["event4"].should == 4
        JSON[last_response.body]["event5"].should == 5
      end

      it "defaults to the last hour" do
        event_happened(:at => Time.now - 10*MINUTE)
        event_happened(
          :event => event2,
          :at => Time.now - 70*MINUTE,
          :count => 94555)

        post_multicount([event, event2])

        JSON[last_response.body][event].should == 1
        JSON[last_response.body][event2].should == 0
      end

      it "uses zeros for unknown events" do
        post_multicount ['mystery-event']

        JSON[last_response.body]["mystery-event"].should == 0
      end

      it "does not crash when requesting 0 events" do
        post_multicount

        JSON[last_response.body].should == {}
      end

      it "honors the :granularity param" do
        event_happened(
          :at => Time.now - Duckweed::App::INTERVAL[:minutes][:expiry] - 1,
          :times => 7)

        post_multicount([event], :granularity => 'hours')

        JSON[last_response.body][event].should == 7
      end

      it "honors the :quantity param" do
        event_happened(:at => Time.now - 5*MINUTE)
        event_happened(:at => Time.now - 10*MINUTE, :times => 2)

        post_multicount([event], :quantity => '5')

        JSON[last_response.body][event].should == 1
      end

      context 'with a quantity that exceeds the expiry limit' do
        it 'returns a 413 status code' do
          post "/multicount", {
            :events => [event],
            :granularity => :minutes,
            :quantity => 5000}
          last_response.status.should == 413
        end
      end
    end
  end
end
