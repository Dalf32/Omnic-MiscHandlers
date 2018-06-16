# owl_stage.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'identifiable'

class OwlStage
  include Identifiable

  attr_accessor :weeks, :standings

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
