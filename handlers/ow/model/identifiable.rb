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
end
