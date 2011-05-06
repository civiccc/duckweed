require "spec_helper"


describe Duckweed::App do
  def app
    described_class
  end

  it "says hello to the world" do
    get '/hello'
    last_response.body.should =~ /world/i
  end
end
