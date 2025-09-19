# frozen_string_literal: true

class NameElement
  attr_reader :name, :length

  def initialize(name:, singular: false, repeatable: false, length: 0)
    @name = name
    @singular = singular
    @repeatable = repeatable
    @length = length
  end

  def singular?
    @singular
  end

  def repeatable?
    @repeatable
  end

  def +(other_name)
    "#{self} #{other_name}"
  end
  alias combine +

  def to_s
    @name
  end
end

module StringExt
  def +(other_name)
    return "#{self} #{other_name}" if other_name.is_a?(NameElement)

    super(other_name)
  end
end
String.prepend(StringExt)
