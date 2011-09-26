module Duckweed
  class Event < Struct.new(:name, :granularity, :quantity, :offset, :now)
    DEFAULT_OFFSET = 1
    MINUTE         = 60
    HOUR           = MINUTE * 60
    DAY            = HOUR * 24
    YEAR           = DAY * 365

    # The little bit of extra time on each bucket is so that we have a
    # round number of complete buckets available for querying. For
    # example, by having a day and a minute as the expiry time for the
    # :minutes bucket, we let the user query for a full day of
    # minute-resolution data. Were we to use just a day, then a query
    # for a day's worth of data would be met with a 413, since the
    # default offset is 1 (to ignore the current, half-baked bucket),
    # and so the user would have to instead ask for 23 hours and 59
    # minutes' worth of data, causing them to wonder just what kind of
    # idiots wrote this app.
    #
    # There's no technical reason for the extra time; it's purely
    # aesthetic.
    INTERVAL = {
      :minutes => {
        :bucket_size  => MINUTE,
        :expiry       => DAY * 2 + MINUTE,
        :time_format  => '%I:%M%p'    # 10:11AM
      },
      :hours => {
        :bucket_size  => HOUR,
        :expiry       => DAY * 28 + HOUR,
        :time_format  => '%a %I%p'    # Sun 10AM
      },
      :days => {
        :bucket_size  => DAY,
        :expiry       => YEAR * 5 + DAY,
        :time_format  => '%b %d %Y'   # Jan 21 2011
      }
    }

    def self.valid_granularity?(g)
      INTERVAL.has_key?(g)
    end

    def self.bucket_count(granularity)
      INTERVAL[granularity][:expiry] / INTERVAL[granularity][:bucket_size]
    end


    def initialize(*args)
      unless args[0]
        raise ArgumentError, "Event name is required"
      end
      super
    end

    def total_occurrences(args={})
      keys = keys_for(args)
      redis.mget(*keys).map(&:to_i).inject(0, &:+)
    end

    private

    def redis
      Duckweed.redis
    end

    def keys_for(args={})
      now         = (args[:now]         || self.now         || Time.now      ).to_i
      offset      =  args[:offset]      || self.offset      || DEFAULT_OFFSET
      count       =  args[:quantity]    || self.quantity
      granularity =  args[:granularity] || self.granularity

      bucket_name = "duckweed:#{self.name}:#{granularity}"
      newest_bucket_index = (now / INTERVAL[granularity][:bucket_size]) - offset

      # NB: this returns data from most recent to least recent. If
      # ordering is ever a problem, we'll probably want to reverse
      # this so that data comes out oldest-first.
      (0...count).map do |i|
        newest_bucket_index - i
      end.map do |idx|
        "#{bucket_name}:#{idx}"
      end
    end

  end
end
