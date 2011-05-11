require "spec_helper"

describe Duckweed::App do
  let(:app) { described_class }

  describe 'GET /health' do
    it 'succeeds' do
      get '/health'
      last_response.should be_successful
    end

    it 'returns a 200 status code' do
      get '/health'
      last_response.status.should == 200
    end

    it 'responds with "OK"' do
      get '/health'
      last_response.body.should == 'OK'
    end
  end
end
