# owc_region.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'identifiable'

class OwcRegion
  include Identifiable

  attr_accessor :abbreviation, :tournament_id

  def matches?(name)
    super(name) || @abbreviation.casecmp(name).zero?
  end

  def exact_match?(name)
    super(name) || @abbreviation.casecmp(name).zero?
  end

  def eql?(other)
    return false if other.nil?
    return @name == other if other.is_a? String

    @id == other.id
  end

  def to_s
    "#{@name} (#{@abbreviation})"
  end
end
