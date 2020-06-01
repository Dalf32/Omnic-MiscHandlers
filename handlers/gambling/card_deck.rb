# CardDeck
#
# AUTHOR::  Kyle Mullins

require_relative 'playing_card'

class CardDeck
  def initialize(num_decks: 1)
    @cards = num_decks.times.flat_map { generate_deck }
  end

  def num_cards
    @cards.count
  end

  def empty?
    @cards.empty?
  end

  def shuffle
    @cards = @cards.shuffle
    self
  end

  def draw(count = nil)
    return @cards.pop if count.nil?

    count.times.map { @cards.pop }
  end

  private

  def generate_deck
    [:clubs, :spades, :hearts, :diamonds].flat_map do |suit|
      (1..13).map { |rank| PlayingCard.new(rank, suit) }
    end
  end
end
