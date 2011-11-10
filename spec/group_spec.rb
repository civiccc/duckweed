require 'spec_helper'

describe Duckweed::App do
  let(:app) { described_class }
  let(:default_params) { { :auth_token => Duckweed::Token.authorize('abcd') } }
  let(:group) { 'test-group' }
  let(:events) { ['event1', 'event2'] }

  before { freeze_time }

  describe 'GET /group/:group' do
    it_should_behave_like 'pages needing readonly auth' do
      def do_request
        get "/group/#{group}", {}
      end
    end

    context 'with an unused group' do
      it 'succeeds' do
        get "/group/fake-group", default_params
        last_response.should be_successful
      end

      it 'returns nothing' do
        get "/group/fake-group", default_params
        last_response.body.should == '[]'
      end
    end

    context 'with group having recorded events' do
      it 'returns group event keys' do
        events.each do |event|
          event_happened(
            :event => event,
            :group => group)
        end

        get "/group/#{group}", default_params

        JSON[last_response.body].sort.should == events.sort
      end
    end
  end
end
