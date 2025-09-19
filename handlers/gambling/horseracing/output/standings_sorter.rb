# frozen_string_literal: true

require_relative 'race_processor'

class StandingsSorter < RaceProcessor
  def process_leg(race_results)
    sorted_leg = race_results.current_leg.sort_by(&:distance).reverse
    race_results.update_current_leg(sorted_leg)

    next_processor(race_results)
  end
end
