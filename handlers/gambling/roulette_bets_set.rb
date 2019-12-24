# RouletteBetsSet
#
# AUTHOR::  Kyle Mullins

require 'redis-objects'
require_relative 'roulette_bet'

class RouletteBetsSet
  def initialize(server_redis)
    @bets_set = Redis::HashKey.new([server_redis.namespace, 'roulette:bets'])
  end

  def total_bets
    @bets_set.count
  end

  def include?(user_id)
    @bets_set.key?(user_id)
  end
  alias_method :has_bet?, :include?

  def all_bets
    @bets_set.all.map { |user, bet| [user, RouletteBet.from_str(bet)] }.to_h
  end

  def clear_bets
    @bets_set.clear
  end

  def [](user_id)
    RouletteBet.from_str(@bets_set[user_id])
  end
  alias_method :bet, :[]

  def []=(user_id, bet)
    @bets_set[user_id] = bet.to_str
  end
  alias_method :add_bet, :[]=
end
