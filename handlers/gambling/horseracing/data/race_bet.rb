# frozen_string_literal: true

class RaceBet
  attr_reader :server, :channel, :user, :horse, :wager

  def initialize(server:, channel:, user:, horse:, wager:)
    @server = server
    @channel = channel
    @user = user
    @horse = horse
    @wager = wager
  end

  def payout(odds)
    ((1 + (odds * payout_adjust)) * @wager).to_i
  end

  def to_s
    "#{@wager.format_currency} bet on #{@horse} to #{type}"
  end

  def to_hash
    {
      type: type,
      server: @server,
      channel: @channel,
      user: @user,
      horse: @horse,
      wager: @wager
    }
  end

  def self.from_hash(bet_hash)
    type = bet_hash.delete(:type)
    RaceBet.new(**bet_hash).tap do |bet|
      next if type.nil?

      bet.extend(Module.const_get("#{type.capitalize}Bet"))
    rescue NameError
      # We just won't extend the object in this case
      Omnic.logger.warn("Bet not extended, no Module found for type #{type.capitalize}")
    end
  end
end

module WatchBet
  def self.create(**params)
    RaceBet.new(user: nil, horse: nil, wager: nil, **params)
           .tap { |bet| bet.extend(WatchBet) }
  end

  def type
    :watch
  end

  def payout_adjust
    0
  end

  def win?(_results)
    false
  end
end

module WinBet
  def self.create(**params)
    RaceBet.new(**params).tap { |bet| bet.extend(WinBet) }
  end

  def type
    :win
  end

  def payout_adjust
    1
  end

  def win?(results)
    results.standings.flatten.first.name == @horse
  end
end

module ShowBet
  def self.create(**params)
    RaceBet.new(**params).tap { |bet| bet.extend(ShowBet) }
  end

  def type
    :show
  end

  def payout_adjust
    0.5
  end

  def win?(results)
    results.standings.flatten.map(&:name)[0..1].include?(@horse)
  end
end

module PlaceBet
  def self.create(**params)
    RaceBet.new(**params).tap { |bet| bet.extend(PlaceBet) }
  end

  def type
    :place
  end

  def payout_adjust
    1 / 3.0
  end

  def win?(results)
    results.standings.flatten.map(&:name)[0..2].include?(@horse)
  end
end
