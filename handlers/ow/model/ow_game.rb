# ow_game.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'has_status'

class OwGame
  include HasStatus

  attr_reader :id

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

  def draw?
    concluded? && @away_score == @home_score
  end
end
