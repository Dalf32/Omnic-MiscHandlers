# announce_store.rb
#
# AUTHOR::  Kyle Mullins

class AnnounceStore
  def initialize(server_redis)
    @redis = server_redis
  end

  def enabled?
    @redis.exists?(:announce_channel)
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
end
