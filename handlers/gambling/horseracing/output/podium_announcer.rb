# frozen_string_literal: true

require_relative 'race_processor'

class PodiumAnnouncer < RaceProcessor
  def process_leg(race_results)
    if race_results.complete?
      standings = race_results.current_leg.flatten
      cast_text = "**#{standings[0].name}** takes the win! **#{standings[1].name}** comes in second and **#{standings[2].name}** third!"
      race_results.add_cast(cast_text)
    end

    next_processor(race_results)
  end
end
