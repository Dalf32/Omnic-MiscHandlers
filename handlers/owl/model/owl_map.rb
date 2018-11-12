# owl_map.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'identifiable'

class OwlMap
  include Identifiable

  attr_reader :thumbnail

  def basic_info(background:, icon:, thumbnail:, type:)
    @background = background
    @icon = icon
    @thumbnail = thumbnail
    @type = type
    self
  end

  def eql?(other)
    return false if other.nil?
    return @id == other if other.is_a? String

    @id == other.id
  end

  def to_s
    @name
  end
end
