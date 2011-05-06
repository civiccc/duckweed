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
    @data[key] ||= 0
    @data[key] += 1
  end

  def get(key)
    @data[key]
  end

  def keys(pattern)
    # pattern is a Redis-style pattern, not a Ruby regexp.
    re = regex_from_redis_pattern(pattern)
    @data.keys.find_all {|k| k =~ re}
  end

  def mget(*keys)
    keys.map {|k| @data[k] }
  end

  def expire(key, seconds)
    1
  end

  private
  def regex_from_redis_pattern(pattern)
    # TODO: respect \ as escape character
    pattern.
      gsub('?', '.').
      gsub('*', '.*')
  end
end
