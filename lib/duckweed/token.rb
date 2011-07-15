module Duckweed
  class Token
    TOKEN_HASH_NAME = 'duckweed:auth_tokens'

    def self.authorize(str)
      redis.hset(TOKEN_HASH_NAME, str, "rw")
      str
    end

    def self.authorized?(str)
      redis.hexists(TOKEN_HASH_NAME, str)
    end

    def self.deauthorize(str)
      redis.hdel(TOKEN_HASH_NAME, str)
    end

    def self.all
      redis.hgetall(TOKEN_HASH_NAME).keys
    end

    private
    def self.redis
      Duckweed.redis
    end

  end
end
