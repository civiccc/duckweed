require 'spec_helper'

describe Duckweed::Token do
  context ".authorize(token, perms)" do
    it "returns token" do
      described_class.authorize('foo', 'rw').should == 'foo'
    end

    it "makes .authorized?(token, p) true for p in perms" do
      token = "salty-sea-dogs"

      described_class.authorized?(token, 'r').should be_false
      described_class.authorized?(token, 'w').should be_false
      described_class.authorize(token, 'rw')
      described_class.authorized?(token, 'r').should be_true
      described_class.authorized?(token, 'w').should be_true
    end

    it "does not affect .authorized?(token, p) for p not in perms" do
      token = "pieces-of-eight"
      described_class.authorize(token, 'rw')
      described_class.authorized?(token, 'x').should be_false
    end

    it "raises an error on nil" do
      lambda do
        described_class.authorize(nil)
      end.should raise_error(ArgumentError)
    end

    it "raises an error on empty string" do
      lambda do
        described_class.authorize("")
      end.should raise_error(ArgumentError)
    end
  end

  context ".deauthorize(token)" do
    it "makes .authorized?(token, X) false" do
      token = "scurvy-cur"
      described_class.authorize(token, 'p')
      described_class.authorized?(token, 'p').should be_true

      described_class.deauthorize(token)
      described_class.authorized?(token, 'p').should be_false
    end
  end
end 
