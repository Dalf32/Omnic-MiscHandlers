# frozen_string_literal: true

require 'delegate'
require_relative 'race_bet'
require_relative 'race_results'

class ScheduledRace < SimpleDelegator
  attr_reader :time, :bets, :entrants, :race_id

  def initialize(race: nil, time:, bets: [], race_id: nil)
    super(race)

    @time = time
    @bets = bets
    @entrants = []
    @race_id = race_id # only used for deserialization
  end

  def race
    __getobj__
  end

  def race=(race)
    __setobj__(race)
  end

  def stable_horses(racing_horses = nil)
    if racing_horses.nil?
      horses.each { |horse| @entrants << horse.stable }
    else
      @entrants = racing_horses
    end
  end

  def add_bet(bet)
    @bets << bet
  end
  alias << add_bet

  def bets?
    !@bets.empty?
  end

  def run(processor)
    race_results = RaceResults.new(length)

    length.times.each do
      2.times do
        @entrants.each { |horse| horse.run_furlong }
      end

      race_results << @entrants
      processor.process_leg(race_results)
    end

    race_results
  end

  def to_s
    race_str(@entrants.sort_by(&:odds).reverse)
  end

  def to_hash
    {
      race_id: id,
      time: @time,
      bets: @bets.map(&:to_hash)
    }
  end

  def self.from_hash(sched_race_hash)
    sched_race_hash[:bets] = sched_race_hash[:bets].map { |bet_hash| RaceBet.from_hash(bet_hash) }
    ScheduledRace.new(**sched_race_hash)
  end
end
