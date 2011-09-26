require 'spec_helper'

describe Duckweed::Event do
  context "#new" do
    it "raises an error if you don't provide a name" do
      lambda do
        described_class.new
      end.should raise_error(ArgumentError)
    end
  end
end
