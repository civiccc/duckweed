require "spec_helper"

describe Duckweed::App do
  def app
    described_class
  end

  it "says hello to the world" do
    get '/hello'
    last_response.body.should =~ /world/i
  end

  describe "POST /track/:event" do
    let(:event) { 'test-event-47781' }

    before do
      @now = Time.now
      Time.stub!(:now).and_return(@now)
    end

    context 'with a new event' do
      it 'succeeds' do
        post "/track/#{event}"
        last_response.should be_successful
      end

      it 'responds with "OK"' do
        post "/track/#{event}"
        last_response.body.should == "OK"
      end

      it "increments a key with minute-granularity in Redis" do
        expect { post "/track/#{event}" }.to change {
          Duckweed.redis.get("duckweed:#{event}:minutes:#{@now.to_i / 60}")
        }.from(nil).to(1)
      end

      it "increments a key with hour-granularity in Redis" do
        expect { post "/track/#{event}" }.to change {
          Duckweed.redis.get("duckweed:#{event}:hours:#{@now.to_i / 3600}")
        }.from(nil).to(1)
      end

      it "increments a key with day-granularity in Redis" do
        expect { post "/track/#{event}" }.to change {
          Duckweed.redis.get("duckweed:#{event}:days:#{@now.to_i / 86400}")
        }.from(nil).to(1)
      end
    end

    context 'with a previously-seen event' do
      before do
        post "/track/#{event}"
      end

      it 'succeeds' do
        post "/track/#{event}"
        last_response.should be_successful
      end

      it 'responds with "OK"' do
        post "/track/#{event}"
        last_response.body.should == "OK"
      end

      it "increments a key with minute-granularity in Redis" do
        expect { post "/track/#{event}" }.to change {
          Duckweed.redis.get("duckweed:#{event}:minutes:#{@now.to_i / 60}")
        }.by(1)
      end

      it "increments a key with hour-granularity in Redis" do
        expect { post "/track/#{event}" }.to change {
          Duckweed.redis.get("duckweed:#{event}:hours:#{@now.to_i / 3600}")
        }.by(1)
      end

      it "increments a key with day-granularity in Redis" do
        expect { post "/track/#{event}" }.to change {
          Duckweed.redis.get("duckweed:#{event}:days:#{@now.to_i / 86400}")
        }.by(1)
      end
    end
  end
end
