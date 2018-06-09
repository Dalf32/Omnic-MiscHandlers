# owl_stage.rb
#
# AUTHOR::  Kyle Mullins

class OwlStage
  attr_reader :id, :name
  attr_accessor :weeks, :standings

  def initialize(id:, name:)
    @id = id
    @name = name
  end

  def in_progress?
    @weeks.any?(&:in_progress?)
  end

  def current_week
    @weeks.find(&:in_progress?)
  end

  def matches
    @weeks.map(&:matches).flatten
  end

  def to_s
    @name
  end
end
