# owl_stage.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'identifiable'
require_relative 'has_season'

class OwlStage
  include Identifiable
  include HasSeason

  attr_accessor :weeks, :standings, :slug

  def in_progress?
    @weeks.any?(&:in_progress?)
  end

  def upcoming?
    @weeks.any?(&:upcoming?)
  end

  def current_week
    @weeks.find(&:in_progress?)
  end

  def upcoming_week
    @weeks.find(&:upcoming?)
  end

  def matches
    @weeks.map(&:matches).flatten
  end

  def number
    @slug.nil? ? @id : @slug[-1]
  end

  def to_s
    @name
  end
end
