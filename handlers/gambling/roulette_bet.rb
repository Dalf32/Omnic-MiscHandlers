# RouletteBet
#
# AUTHOR::  Kyle Mullins

class RouletteBet
  attr_accessor :wager

  def self.create(bet_str)
    bet = bets.find { |b| b.matches?(bet_str) } || InvalidBet
    bet.new(bet_str)
  end

  def self.bets
    @bets ||= []
  end

  def self.inherited(subclass)
    bets << subclass
  end

  def self.paytable_str
    format("%s = x%.3g", description, payout)
  end

  def initialize(bet_str)
    @bet = bet_str.downcase
  end

  def description
    self.class.description
  end

  def payout
    self.class.payout
  end

  def valid?
    true
  end

  def with_wager(wager)
    @wager = wager
    self
  end

  def winnings
    @wager * payout
  end

  def to_s
    return "$#{@wager} on #{@bet.capitalize}" unless wager.nil?

    @bet.capitalize
  end

  # Redis serialization

  def to_str
    "#{@bet}|#{@wager}"
  end

  def self.from_str(bet_str)
    bet_str, wager = *bet_str.split('|')
    RouletteBet.create(bet_str).with_wager(wager.to_i)
  end
end

class SingleBet < RouletteBet
  def self.matches?(bet_str)
    %w(0 00).include?(bet_str) || (1..36).include?(bet_str.to_i)
  end

  def self.description
    'Any single number, 0-36 or 00: Wins if the ball lands on the given number.'
  end

  def self.payout
    38
  end

  def win?(pocket)
    pocket.number == @bet
  end
end

class BasketBet < RouletteBet
  def self.matches?(bet_str)
    bet_str.casecmp('basket').zero?
  end

  def self.description
    'Basket: Wins on 0, 00, 1, 2, or 3.'
  end

  def self.payout
    7.6
  end

  def win?(pocket)
    %w(0 00 1 2 3).include?(pocket.number)
  end
end

class LowHighBet < RouletteBet
  def self.matches?(bet_str)
    %w(low high).include?(bet_str.downcase)
  end

  def self.description
    'Low or High: If Low, wins on 1-18. If High, wins on 19-36.'
  end

  def self.payout
    2 + 1.0/9.0
  end

  def win?(pocket)
    (low? ? (1..18) : (19..36)).include?(pocket.number.to_i)
  end

  private

  def low?
    @bet.casecmp('low').zero?
  end

  def high?
    @bet.casecmp('high').zero?
  end
end

class RedBlackBet < RouletteBet
  def self.matches?(bet_str)
    %w(red black).include?(bet_str.downcase)
  end

  def self.description
    'Red or Black: Wins if the ball lands on a pocket of the given color.'
  end

  def self.payout
    2 + 1.0/9.0
  end

  def win?(pocket)
    pocket.color.casecmp(@bet).zero?
  end
end

class EvenOddBet < RouletteBet
  def self.matches?(bet_str)
    %w(even odd).include?(bet_str.downcase)
  end

  def self.description
    'Even or Odd: Even wins on any even number. Odd wins on any odd number.'
  end

  def self.payout
    2 + 1.0/9.0
  end

  def win?(pocket)
    even? ? pocket.number.to_i.even? : pocket.number.to_i.odd?
  end

  private

  def even?
    @bet == 'even'
  end

  def odd?
    @bet == 'odd'
  end
end

class DozenBet < RouletteBet
  def self.matches?(bet_str)
    /[pdm]12/i.match?(bet_str)
  end

  def self.description
    'P12, M12, or D12: If P12, wins on 1-12. If M12, wins on 13-24. If D12, wins on 25-36.'
  end

  def self.payout
    3 + 1.0/6.0
  end

  def win?(pocket)
    dozen_range.include?(pocket.number.to_i)
  end

  private

  def dozen_range
    case @bet[0]
    when 'p'
      (1..12)
    when 'd'
      (13..24)
    when 'm'
      (25..36)
    else
      0
    end
  end
end

class SnakeBet < RouletteBet
  def self.matches?(bet_str)
    bet_str.casecmp('snake').zero?
  end

  def self.description
    'Snake: Wins on any of 1, 5, 9, 12, 14, 16, 19, 23, 27, 30, 32, 34.'
  end

  def self.payout
    3 + 1.0/6.0
  end

  def win?(pocket)
    [1, 5, 9, 12, 14, 16, 19, 23, 27, 30, 32, 34].include?(pocket.number.to_i)
  end
end

class InvalidBet < RouletteBet
  def self.matches?(_bet_str)
    false
  end

  def valid?
    false
  end

  def self.payout
    0
  end

  def win?(_pocket)
    false
  end
end
