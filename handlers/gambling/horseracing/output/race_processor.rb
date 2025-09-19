# frozen_string_literal: true

class RaceProcessor
  def initialize
    @successor = nil
  end

  def process_leg(race_results)
    next_processor(race_results)
  end

  def then(successor)
    if @successor.nil?
      @successor = successor
    else
      @successor.then(successor)
    end

    self
  end

  protected

  def next_processor(race_results)
    @successor.nil? ? race_results : @successor.process_leg(race_results)
  end
end

SilentAnnouncer = RaceProcessor
