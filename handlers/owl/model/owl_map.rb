# owl_map.rb
#
# AUTHOR::  Kyle Mullins

class OwlMap
  attr_reader :id, :name, :thumbnail

  def initialize(id:, name:)
    @id = id
    @name = name
  end

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
