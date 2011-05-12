shared_examples_for 'pages with auth' do
  context 'without an authentication token' do
    it 'fails' do
      do_request
      last_response.should_not be_successful
    end

    it 'returns a 403 status code' do
      do_request
      last_response.status.should == 403
    end

    it 'responds with "forbidden"' do
      do_request
      last_response.body.should =~ /forbidden/i
    end
  end
end
