# announce_store.rb
#
# AUTHOR::  Kyle Mullins

class AnnounceStore
  def initialize(server_redis)
    @redis = server_redis
  end

  def enabled?
    @redis.exists(:announce_channel)
  end

  def enabled_for_user?(user)
    @redis.sismember(:announce_users, user.id)
  end

  def channel
    @redis.get(:announce_channel)
  end

  def channel=(channel)
    @redis.set(:announce_channel, channel.id)
  end

  def clear_channel
    @redis.del(:announce_channel)
  end

  def users
    @redis.smembers(:announce_users)
  end

  def add_user(user)
    @redis.sadd(:announce_users, user.id)
  end

  def remove_user(user)
    @redis.srem(:announce_users, user.id)
  end

  def announce_level
    @redis.get(:announce_level)
  end

  def announce_level=(level)
    @redis.set(:announce_level, level)
  end

  def clear_user_cache(user)
    # Expire the key instead of deleting so we are resilient to rapid toggling
    @redis.expire(cache_key(user.id), 300)
  end

  def cache_stream_title(user)
    cache_key = cache_key(user.id)
    server_redis.set(cache_key, user.game)
    # Set to expire in 24 hours just in case we don't get the event
    server_redis.expire(cache_key, 86_400)
  end

  def cached_title(user)
    @redis.get(cache_key(user.id))
  end

  def title_cached?(user)
    @redis.exists(cache_key(user.id))
  end

  private

  def cache_key(user_id)
    "stream_cache:#{user_id}"
  end
end
