# frozen_string_literal: true

class NameElement
  attr_reader :name, :length

  def initialize(name:, singular: false, chainable: false, length: 0)
    @name = name
    @singular = singular
    @chainable = chainable
    @length = length
  end

  def singular?
    @singular
  end

  def chainable?
    @chainable
  end

  def +(other_name)
    CompoundNameElement.new(self, other_name)
  end
  alias combine +

  def to_s
    @name
  end
end

class CompoundNameElement < NameElement
  def initialize(*name_elements)
    @name_elements = name_elements
  end

  def +(other_name)
    @name_elements << other_name
    self
  end
  alias combine +

  def to_s
    @name_elements.join(' ')
  end
end
