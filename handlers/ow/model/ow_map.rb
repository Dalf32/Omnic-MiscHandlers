# ow_map.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'identifiable'

class OwMap
  include Identifiable

  attr_reader :thumbnail

  def basic_info(icon:, thumbnail:, type:)
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
end
