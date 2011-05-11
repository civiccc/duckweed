# Simple mock Redis library. Only implements GET, INCR, MGET, KEYS, and
# EXPIRE. (EXPIRE is implemented as a noop, so don't rely on it.)

class MockRedis
  def initialize
    reset!
  end

  def reset!
    @data = {}
  end

  def incr(key)
    incrby(key, 1)
  end

  def incrby(key, increment)
    @data[key] ||=0
    @data[key] += increment
  end

  def get(key)
    if v = @data[key]
      v.to_s
    end
  end

  def keys(pattern)
    # pattern is a Redis-style pattern, not a Ruby regexp.
    re = regex_from_redis_pattern(pattern)
    @data.keys.find_all {|k| k =~ re}
  end

  def mget(*keys)
    keys.map {|k| get(k)}
  end

  def expire(key, seconds)
    @data[key] ? 1 : 0
  end

  private

  def regex_from_redis_pattern(pattern)
    regexp = pattern.scan(%r/(\\.)|(.)/).map do |pair|
      if pair.first # this is backslash escape
        Regexp.escape(pair.first[1])
      else          # everything else
        case pair.last
        when '?'
          '.'
        when '*'
          '.*'
        else
          Regexp.escape(pair.last)
        end
      end
    end.join
    Regexp.new(regexp)
  end
end
