require 'spec_helper'

describe Duckweed::UtilityMethods do
  let(:app) {
    object = Object.new
    object.extend(described_class)
    object
  }

  describe '#interpolate' do
    context 'with no values' do
      it 'returns an empty array' do
        app.interpolate.should == []
      end
    end

    context 'with a single value' do
      it 'returns the value in an array' do
        app.interpolate(5).should == [5]
      end
    end

    context 'with nil' do
      it 'returns 0 in an array' do
        app.interpolate(nil).should == [0]
      end
    end

    context 'with a run of nils' do
      it 'returns 0s in an array' do
        app.interpolate(nil, nil, nil ,nil).should ==[0, 0, 0, 0]
      end
    end

    context 'with a run of values' do
      it 'returns the values' do
        app.interpolate(2, 4, 8, 5).should == [2, 4, 8, 5]
      end
    end

    context 'with nils at the start of the run' do
      it 'replaces a single nil with the first found actual value' do
        # note we make interpolated values floats for division
        app.interpolate(nil, 4, 3).should == [4.0, 4, 3]
      end

      it 'replaces multiple nils with the first found actual value' do
        app.interpolate(nil, nil, 2, 10).should == [2.0, 2.0, 2, 10]
      end
    end

    context 'with nils at the end of the run' do
      it 'replaces a single nil with the last seen actual value' do
        app.interpolate(5, 10, nil).should == [5, 10, 10.0]
      end

      it 'replaces multiple nils with the last seen actual value' do
        app.interpolate(5, 10, nil, nil).should == [5, 10, 10.0, 10.0]
      end
    end

    context 'with nils in the middle of the run' do
      it 'replaces a single nil with a value at the mid-point between adjacent values' do
        app.interpolate(5, nil, 10).should == [5, 7.5, 10]  # positive slope
        app.interpolate(8, nil, 8).should == [8, 8.0, 8]    # flat
        app.interpolate(6, nil, 2).should == [6, 4.0, 2]    # negative slope
      end

      it 'replaces multiple nils with interpolated values' do
        app.interpolate(5, nil, nil, 8).should == [5, 6.0, 7.0, 8]
        app.interpolate(2, nil, nil, 2).should == [2, 2.0, 2.0, 2]
        app.interpolate(15, nil, nil, 0).should == [15, 10.0, 5.0, 0]
      end
    end
  end
end
