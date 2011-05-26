shared_examples_for 'granular checks' do
  before do
    event_happened(:times => 2,
      :at => @now - 2*Duckweed::App::INTERVAL[granularity][:bucket_size])
    event_happened(:times => 2,
      :at => @now -   Duckweed::App::INTERVAL[granularity][:bucket_size])
  end

  it 'succeeds' do
    get "/check/#{event}/#{granularity}/1",
        default_params.merge(:threshold => 1)
    last_response.should be_successful
  end

  context 'when the count is < the given threshold' do
    let(:params_with_threshold) { default_params.merge(:threshold => 3) }

    it 'responds with BAD' do
      get "/check/#{event}/#{granularity}/1", params_with_threshold
      last_response.body.should =~ /BAD/
    end

    it 'tells you what the actual count is' do
      get "/check/#{event}/#{granularity}/1", params_with_threshold
      last_response.body.should =~ /2 < 3/
    end
  end

  context 'when the count is >= the given threshold' do
    let(:params_with_threshold) { default_params.merge(:threshold => 1) }

    it 'responds with GOOD' do
      get "/check/#{event}/#{granularity}/1", params_with_threshold
      last_response.body.should =~ /GOOD/
    end

    it 'tells you the actual count' do
      get "/check/#{event}/#{granularity}/1", params_with_threshold
      last_response.body.should =~ /2/
    end

    it 'counts events specified within the timespan' do
      get "/check/#{event}/#{granularity}/3", params_with_threshold
      last_response.body.should =~ /4/
    end
  end

  context 'when the threshold is missing' do
    it 'responds with ERROR' do
      get "/check/#{event}/#{granularity}/1", default_params
      last_response.body.should =~ /ERROR/
    end

    it 'returns a 400 status code' do
      get "/check/#{event}/#{granularity}/1", default_params
      last_response.status.should == 400
    end

    it 'tells you the threshold is missing' do
      get "/check/#{event}/#{granularity}/1", default_params
      last_response.body.should =~ /threshold/
    end
  end
end
