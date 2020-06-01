# PlayingCard
#
# AUTHOR::  Kyle Mullins

class PlayingCard
  attr_reader :rank, :suit

  def initialize(rank, suit)
    @rank = rank
    @suit = suit
  end

  def format(rank_formats, suit_formats)
    rank_formats[@rank] + suit_formats[@suit]
  end

  def eql?(other)
    return false unless other.is_a?(PlayingCard)

    @rank == other.rank && @suit == other.suit
  end

  def to_s
    rank_formats = Hash.new { |_, k| k.to_s }
    suit_formats = Hash.new { |_, k| k.to_s[0].capitalize }
    format(rank_formats, suit_formats)
  end
end
