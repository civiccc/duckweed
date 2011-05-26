require 'spec_helper'

describe Duckweed::App do
  let(:event) { 'test-event-47781' }
  let(:app) { described_class }
  let(:default_params) { { :auth_token => Duckweed::AUTH_TOKENS.first } }

  before { freeze_time }

  describe 'GET /check/:event' do
    let (:params_with_threshold) { default_params.merge(:threshold => 3) }

    it_should_behave_like 'pages with auth' do
      def do_request
        get "/check/#{event}", {}
      end
    end

    it 'succeeds' do
      get "/check/#{event}", params_with_threshold
      last_response.should be_successful
    end

    context 'when the count is < the given threshold' do
      before do
        event_happened(:times => 1, :at => @now - 60)
      end

      it 'responds with BAD' do
        get "/check/#{event}", params_with_threshold
        last_response.body.should =~ /BAD/
      end

      it 'tells you what the actual count is' do
        get "/check/#{event}", params_with_threshold
        last_response.body.should =~ /1 < 3/
      end
    end

    context 'when the count is >= the given threshold' do
      before do
        event_happened(:times => 5, :at => @now - 60)
      end

      it 'responds with GOOD' do
        get "/check/#{event}", params_with_threshold
        last_response.body.should =~ /GOOD/
      end

      it 'tells you the actual count' do
        get "/check/#{event}", params_with_threshold
        last_response.body.should =~ /5/
      end
    end

    context 'when the threshold is missing' do
      it 'responds with ERROR' do
        get "/check/#{event}", default_params
        last_response.body.should =~ /ERROR/
      end

      it 'returns a 400 status code' do
        get "/check/#{event}", default_params
        last_response.status.should == 400
      end

      it 'tells you the threshold is missing' do
        get "/check/#{event}", default_params
        last_response.body.should =~ /threshold/
      end
    end
  end

  describe 'GET /check/:event/:granularity/:quantity' do
    %w[minutes hours days].each do |granularity|
      context "with #{granularity} granularity" do
        it_should_behave_like 'granular checks' do
          let(:granularity) { granularity.to_sym }
        end
      end
    end
  end
end
