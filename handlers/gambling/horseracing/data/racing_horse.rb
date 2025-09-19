# frozen_string_literal: true

require 'delegate'

class RacingHorse < SimpleDelegator
  attr_reader :distance
  attr_accessor :odds

  def self.stable(horse)
    RacingHorse.new(horse: horse,
                    speed_adjust: rand(HorseracingRules.race_day_variance),
                    power_adjust: rand(HorseracingRules.race_day_variance),
                    stamina_adjust: rand(HorseracingRules.race_day_variance))
  end

  def initialize(horse: nil, speed_adjust:, power_adjust:, stamina_adjust:, odds: nil)
    super(horse)

    @speed_adjust = speed_adjust
    @power_adjust = power_adjust
    @stamina_adjust = stamina_adjust
    @odds = odds

    @distance = 0
    @current_speed = 0
    @remaining_stamina = horse.nil? ? 0 : stamina
  end

  def horse=(horse)
    __setobj__(horse)
    @remaining_stamina = stamina
    horse
  end

  def speed
    horse.speed * @speed_adjust
  end

  def power
    horse.power * @power_adjust
  end

  def stamina
    (horse.stamina * @stamina_adjust).to_i
  end

  def run_furlong
    prev_speed = @current_speed
    @current_speed = @remaining_stamina.zero? ? @current_speed - (power / 2) : @current_speed + power
    @current_speed = @current_speed.clamp(power, speed)
    @distance += (prev_speed + @current_speed) / 2
    @remaining_stamina = (@remaining_stamina - 1).clamp(0, stamina)
    @distance
  end

  def odds_str
    find_odds_set.first
  end

  def odds_float
    find_odds_set[1]
  end

  def to_s
    "#{odds_str.ljust(4)} | #{horse.to_s}"
  end

  def to_hash
    {
      speed_adjust: @speed_adjust,
      power_adjust: @power_adjust,
      stamina_adjust: @stamina_adjust,
      odds: @odds
    }
  end

  def self.from_hash(racing_horse_hash)
    RacingHorse.new(**racing_horse_hash)
  end

  private

  def horse
    __getobj__
  end

  def find_odds_set
    HorseracingRules.odds_map
                    .map { |str, float, points| [str, float, (points - @odds).abs] }
                    .min_by(&:last)
  end
end
