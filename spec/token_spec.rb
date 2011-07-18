require 'spec_helper'

describe Duckweed::Token do
  context ".authorize(token, perms)" do
    it "returns token" do
      Duckweed::Token.authorize('foo', 'rw').should == 'foo'
    end

    it "makes .authorized?(token, p) true for p in perms" do
      token = "salty-sea-dogs"

      Duckweed::Token.authorized?(token, 'r').should be_false
      Duckweed::Token.authorized?(token, 'w').should be_false
      Duckweed::Token.authorize(token, 'rw')
      Duckweed::Token.authorized?(token, 'r').should be_true
      Duckweed::Token.authorized?(token, 'w').should be_true
    end

    it "does not affect .authorized?(token, p) for p not in perms" do
      token = "pieces-of-eight"
      Duckweed::Token.authorize(token, 'rw')
      Duckweed::Token.authorized?(token, 'x').should be_false
    end

    it "raises an error on nil" do
      lambda do
        Duckweed::Token.authorize(nil)
      end.should raise_error(ArgumentError)
    end

    it "raises an error on empty string" do
      lambda do
        Duckweed::Token.authorize("")
      end.should raise_error(ArgumentError)
    end
  end

  context ".deauthorize(token)" do
    it "makes .authorized?(token, X) false" do
      token = "scurvy-cur"
      Duckweed::Token.authorize(token, 'p')
      Duckweed::Token.authorized?(token, 'p').should be_true

      Duckweed::Token.deauthorize(token)
      Duckweed::Token.authorized?(token, 'p').should be_false
    end
  end
end 
