# pin_vote.rb
#
# AUTHOR:: Kyle Mullins

require 'redis-objects'

class PinVoteStore
  THRESHOLD_KEY = :threshold

  def initialize(server_redis)
    @redis = server_redis
    @messages_set = Redis::Set.new([@redis.namespace, :messages])
  end

  def threshold
    return 5 unless @redis.exists?(THRESHOLD_KEY)

    @redis.get(THRESHOLD_KEY).to_i
  end

  def threshold=(new_threshold)
    @redis.set(THRESHOLD_KEY, new_threshold)
  end

  def vote_pinned?(message_id)
    @messages_set.include?(message_id)
  end

  def pin(message_id)
    @messages_set.add(message_id)
  end

  def unpin(message_id)
    @messages_set.delete(message_id)
  end
end
