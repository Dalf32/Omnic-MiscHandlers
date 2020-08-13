# user_stream_store.rb
#
# AUTHOR::  Kyle Mullins

class UserStreamStore
  def initialize(user_redis)
    @redis = user_redis
  end

  def cached_title
    @redis.get(:stream_title)
  end

  def title_cached?
    @redis.exists(:stream_title)
  end

  def cache_stream_title(title)
    @redis.set(:stream_title, title)
    # Set to expire in 24 hours just in case we don't get the event
    @redis.expire(:stream_title, 86_400)
  end

  def clear_stream_title
    # Expire the key instead of deleting so we are resilient to rapid toggling
    @redis.expire(:stream_title, 300)
  end
end
