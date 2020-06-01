# CardTable
#
# AUTHOR::  Kyle Mullins

require_relative 'card_hand'

class CardTable
  attr_reader :dealer_hand

  def initialize(players, deck)
    @player_hands = players.map { |player| [player, CardHand.new] }.to_h
    @deck = deck
    @dealer_hand = CardHand.new
  end

  def shuffle
    @deck.shuffle
  end

  def all_players
    @player_hands.keys
  end

  def hand(player)
    @player_hands[player]
  end

  def deal_cards_to(player, num_cards)
    @deck.draw(num_cards).tap { |cards| @player_hands[player].add_cards(*cards) }
  end

  def deal_cards(players, num_cards)
    players.map { |player| [player, deal_cards_to(player, num_cards)] }.to_h
  end

  def dealer_draw(num_cards)
    @deck.draw(num_cards).tap { |cards| @dealer_hand.add_cards(*cards) }
  end
end
