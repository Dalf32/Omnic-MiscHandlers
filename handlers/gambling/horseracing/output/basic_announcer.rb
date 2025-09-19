# frozen_string_literal: true

require_relative '../data/racing_horse'
require_relative 'race_processor'

class BasicAnnouncer < RaceProcessor
  def process_leg(race_results)
    cast_text = "Leg ##{race_results.current_leg_num}:\n  #{format_standings(race_results.current_leg)}"
    race_results.add_cast(cast_text)

    next_processor(race_results)
  end

  private

  def format_standings(standings)
    standings.map { |horse_group| format_horse_group(horse_group) }.join("\n  ")
  end

  def format_horse_group(horse_group)
    return horse_group.name unless horse_group.is_a?(Enumerable)

    horse_group.map(&:name).join("\n  ") + "\n"
  end
end
