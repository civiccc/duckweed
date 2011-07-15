require 'spec_helper'

describe Duckweed::Token do
  context ".authorize(token)" do
    it "returns token" do
      described_class.authorize('foo').should == 'foo'
    end

    it "makes .authorized?(token) true" do
      token = "salty-sea-dogs"

      described_class.authorized?(token).should be_false
      described_class.authorize(token)
      described_class.authorized?(token).should be_true
    end
  end

  context ".deauthorize(token)" do
    it "makes .authorized?(token) false" do
      token = "scurvy-cur"
      described_class.authorize(token)
      described_class.authorized?(token).should be_true

      described_class.deauthorize(token)
      described_class.authorized?(token).should be_false
    end
  end
end 
