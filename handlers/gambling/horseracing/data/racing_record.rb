# frozen_string_literal: true

class RacingRecord
  attr_reader :races_run, :races_won

  def initialize(races_run: 0, races_won: 0, average_placement: nil)
    @races_run = races_run
    @races_won = races_won
    @average_placement = average_placement
  end

  def average_placement
    @average_placement.nil? ? HorseracingRules.championship_entrant_range.max : @average_placement
  end

  def add_result(placement)
    @races_run += 1
    @races_won += 1 if placement == 1

    if @average_placement.nil?
      @average_placement = placement
    else
      @average_placement = ((@average_placement * (@races_run - 1) + placement) / @races_run)
    end
  end

  def to_s
    return 'First Starter' if @races_run.zero?

    "#{@races_won}/#{@races_run}, #{@average_placement.round} APl"
  end

  def to_hash
    {
      races_run: @races_run,
      races_won: @races_won
    }.tap do |record_hash|
      record_hash[:average_placement] = @average_placement unless @average_placement.nil?
    end
  end

  def self.from_hash(record_hash)
    RacingRecord.new(**record_hash)
  end
end
