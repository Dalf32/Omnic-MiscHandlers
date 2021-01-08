# GdqSchedule
#
# AUTHOR::  Kyle Mullins

class GdqSchedule
  attr_reader :event_name, :runs

  def initialize(event_name, runs)
    @event_name = event_name
    @runs = runs
  end

  def live?
    @runs.any?(&:in_progress?)
  end

  def upcoming?
    @runs.any?(&:upcoming?)
  end

  def next(count = 1)
    cur_index = current_or_next_run_index
    return nil if cur_index.nil?

    @runs[cur_index..(cur_index + (count - 1))]
  end

  def current_run
    cur_index = @runs.find_index(&:in_progress?)
    return nil if cur_index.nil?

    @runs[cur_index]
  end

  def previous(count = 1)
    cur_index = current_or_next_run_index
    return nil if cur_index.nil? || cur_index.zero?
    return [@runs.first] if cur_index == 1

    start_index = [cur_index - count, 0].max
    @runs[start_index..(cur_index - 1)]
  end

  def find(game_name)
    @runs.find { |r| r.matches_game?(game_name, full_match: true) } ||
      @runs.find { |r| r.matches_game?(game_name, full_match: false) }
  end

  private

  def current_or_next_run_index
    @runs.find_index { |run| run.in_progress? || run.upcoming? }
  end
end
