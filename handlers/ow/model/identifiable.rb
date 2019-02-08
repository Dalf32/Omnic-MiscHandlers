# identifiable.rb
#
# AUTHOR::  Kyle Mullins

module Identifiable
  attr_reader :id, :name

  def initialize(id:, name:)
    @id = id
    @name = name
  end

  def matches?(name)
    @name.downcase.include?(name.downcase)
  end

  def exact_match?(name)
    @name.casecmp(name).zero?
  end

  def eql?(other)
    return false if other.nil?
    return @id == other if other.is_a? Numeric
    return @name == other if other.is_a? String

    @id == other.id
  end

  def hash
    @name.hash
  end

  def to_s
    @name
  end
end
