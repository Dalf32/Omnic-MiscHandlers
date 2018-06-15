# owl_game.rb
#
# AUTHOR::  Kyle Mullins

class OwlGame
  attr_reader :id

  PENDING_STATE = 'PENDING'.freeze
  IN_PROGRESS_STATE = 'IN_PROGRESS'.freeze
  CONCLUDED_STATE = 'CONCLUDED'.freeze

  def initialize(id:)
    @id = id
  end

  def basic_info(map_id:, state:)
    @map_id = map_id
    @state = state
    self
  end

  def result(away_score:, home_score:)
    @away_score = away_score
    @home_score = home_score
    self
  end

  def away_score
    @away_score || '-'
  end

  def home_score
    @home_score || '-'
  end

  def map(all_maps)
    all_maps.find { |map| map.eql?(@map_id) }
  end

  def pending?
    @state == PENDING_STATE
  end

  def in_progress?
    @state == IN_PROGRESS_STATE
  end

  def concluded?
    @state == CONCLUDED_STATE
  end
end
