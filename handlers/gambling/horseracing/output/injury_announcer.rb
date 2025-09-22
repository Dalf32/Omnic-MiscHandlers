# frozen_string_literal: true

require_relative 'race_processor'

class InjuryAnnouncer < RaceProcessor
  def initialize
    super
    @announced_injuries = []
  end

  def process_leg(race_results)
    if race_results.injury?
      (race_results.injuries - @announced_injuries).each do |injured_horse|
        @announced_injuries << injured_horse
        race_results.add_cast("Oh no, it looks like something has happened to #{injured_horse.name}...")
      end
    end

    next_processor(race_results)
  end
end
