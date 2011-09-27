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
      _, values = occurrences(args)
      values.inject(0, &:+)
    end

    def occurrences(args={})
      granularity = args[:granularity] || self.granularity

      times  = indices_for(args).map{|i| index_to_time(i, granularity)}
      keys   = keys_for(args)
      values = redis.mget(*keys).map(&:to_i)
      [times, values]
    end

    private

    def redis
      Duckweed.redis
    end

    def keys_for(args={})
      granularity = args[:granularity] || self.granularity
      bucket_name = "duckweed:#{self.name}:#{granularity}"

      indices_for(args).map do |idx|
        "#{bucket_name}:#{idx}"
      end
    end

    def index_to_time(index, granularity)
      Time.at(index * INTERVAL[granularity][:bucket_size])
    end

    def indices_for(args={})
      now         = (args[:now]         || self.now         || Time.now      ).to_i
      offset      =  args[:offset]      || self.offset      || DEFAULT_OFFSET
      count       =  args[:quantity]    || self.quantity
      granularity =  args[:granularity] || self.granularity

      if count == :all
        # we have to subtract the offset so that you get all the
        # data you requested without spurious 0s at the start.
        #
        # one could argue that :quantity => :all, :offset => 1 is
        # meaningless, but since the default offset is nonzero, that
        # makes for a bad experience for the caller.
        count = self.class.bucket_count(granularity) - offset
      end

      newest_bucket_index = (now / INTERVAL[granularity][:bucket_size]) - offset

      (0...count).map do |i|
        newest_bucket_index - i
      end.reverse
    end

  end
end
