# CardHand
#
# AUTHOR::  Kyle Mullins

class CardHand
  def initialize
    @cards = []
  end

  def add_cards(*cards)
    @cards += cards
  end

  def evaluate(&block)
    yield @cards
  end

  def to_s
    @cards.map(&:to_s).join(', ')
  end
end
