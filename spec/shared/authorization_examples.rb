shared_examples_for "it needs an authentication token" do
  context 'without an authentication token' do
    before { do_request }

    it 'fails' do
      last_response.should_not be_successful
    end

    it 'returns a 403 status code' do
      last_response.status.should == 403
    end

    it 'responds with "forbidden"' do
      last_response.body.should =~ /forbidden/i
    end
  end
end

shared_examples_for 'pages needing rw auth' do
  it_should_behave_like "it needs an authentication token"

  context 'with a read-only authentication token' do
    before do
      rotoken = 'readonlything'
      Duckweed::Token.authorize(rotoken, 'r')
      authorize rotoken, ''
    end

    it_should_behave_like "it needs an authentication token"
  end
end

shared_examples_for 'pages needing readonly auth' do
  it_should_behave_like "it needs an authentication token"
end
