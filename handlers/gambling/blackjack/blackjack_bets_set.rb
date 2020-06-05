# BlackjackBetsSet
#
# AUTHOR::  Kyle Mullins

require 'redis-objects'

class BlackjackBetsSet
  def initialize(server_redis)
    @bets_set = Redis::HashKey.new([server_redis.namespace, 'blackjack:bets'])
  end

  def total_bets
    @bets_set.count
  end

  def empty?
    total_bets.zero?
  end

  def include?(user_id)
    @bets_set.key?(user_id)
  end
  alias_method :has_bet?, :include?

  def all_bets
    @bets_set.all.map { |user, bet| [user, bet.to_i] }.to_h
  end

  def clear_bets
    @bets_set.clear
  end

  def [](user_id)
    @bets_set[user_id].to_i
  end
  alias_method :bet, :[]

  def []=(user_id, bet)
    @bets_set[user_id] = bet
  end
  alias_method :add_bet, :[]=

  def players
    @bets_set.keys
  end
end
