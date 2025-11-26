# frozen_string_literal: true

class RacingRecord
  attr_reader :races_run, :races_won

  def initialize(races_run: 0, races_won: 0, average_placement: nil,
                 championships: [])
    @races_run = races_run
    @races_won = races_won
    @average_placement = average_placement
    @championships = championships
  end

  def first_starter?
    @races_run.zero?
  end

  def average_placement
    @average_placement.nil? ? HorseracingRules.championship_entrant_range.max : @average_placement
  end

  def add_result(race, placement)
    @races_run += 1
    @races_won += 1 if placement == 1

    if @average_placement.nil?
      @average_placement = placement
    else
      @average_placement = ((@average_placement.to_f * (@races_run - 1) + placement) / @races_run)
    end

    if race.championship? && placement == 1
      @championships << race.to_s_short
    end
  end

  def to_table_cols
    return %w[0 0 -] if first_starter?

    [@races_won, @races_run, @average_placement.round]
  end

  def to_s
    return 'First Starter' if first_starter?

    "#{@races_won}/#{@races_run}, #{@average_placement.round} APl"
  end

  def to_s_detail(newline_indent = '')
    return 'First Starter' if first_starter?

    race_plural = @races_won == 1 ? 'race' : 'races'
    champ_str = "#{newline_indent}Championships won: #{@championships.empty? ? '*None*' : @championships.join(', ')}"
    "Won #{@races_won} #{race_plural} out of #{@races_run} run, with an average placement of #{@average_placement.round}\n#{champ_str}"
  end

  def to_hash
    {
      races_run: @races_run,
      races_won: @races_won,
      championships: @championships
    }.tap do |record_hash|
      record_hash[:average_placement] = @average_placement unless @average_placement.nil?
    end
  end

  def self.from_hash(record_hash)
    RacingRecord.new(**record_hash)
  end
end
