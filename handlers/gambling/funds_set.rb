# FundsSet
#
# AUTHOR::  Kyle Mullins

require 'redis-objects'

class FundsSet
  def initialize(server_redis)
    @funds_set = Redis::SortedSet.new([server_redis.namespace, 'funds'])
  end

  def total_users
    @funds_set.count
  end

  def include?(user_id)
    @funds_set.member?(user_id)
  end

  def [](user_id)
    @funds_set[user_id].to_i
  end
  alias_method :funds, :[]

  def []=(user_id, funds)
    @funds_set[user_id] = funds
  end
  alias_method :update_funds, :[]=

  def rank(user_id)
    total_users - @funds_set.rank(user_id)
  end

  def rank_str(user_id)
    "#{rank(user_id)}/#{total_users}"
  end

  def leaders(num = 10)
    @funds_set[(-1 * num)..-1].reverse
  end
end
