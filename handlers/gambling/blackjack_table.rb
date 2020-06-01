# BlackjackTable
#
# AUTHOR::  Kyle Mullins

require_relative 'card_table'

class BlackjackTable < CardTable
  BLACKJACK = 21

  def player_hand_value(player)
    @player_hands[player].evaluate(&method(:evaluate_hand))
  end

  def player_best_hand_value(player)
    best_hand_value(player_hand_value(player))
  end

  def player_hand_values
    @player_hands.map do |player, hand|
      [player, hand.evaluate(&method(:evaluate_hand))]
    end.to_h
  end

  def player_best_hand_values
    player_hand_values.map do |player, hand_vals|
      [player, best_hand_value(hand_vals)]
    end.to_h
  end

  def dealer_hand_value
    @dealer_hand.evaluate(&method(:evaluate_hand))
  end

  def dealer_best_hand_value
    best_hand_value(dealer_hand_value)
  end

  def player_blackjack?(player)
    hand_blackjack?(player_hand_value(player))
  end

  def players_with_blackjack
    player_hand_values.select { |_, hand_vals| hand_blackjack?(hand_vals) }.keys
  end

  def dealer_blackjack?
    hand_blackjack?(dealer_hand_value)
  end

  def player_busted?(player)
    hand_busted?(player_hand_value(player))
  end

  def players_busted
    player_hand_values.select { |_, hand_vals| hand_busted?(hand_vals) }.keys
  end

  def dealer_busted?
    hand_busted?(dealer_hand_value)
  end

  def player_remaining?(player)
    player_val = player_hand_value(player)
    !hand_busted?(player_val) && !hand_blackjack?(player_val)
  end

  def remaining_players
    player_hand_values.reject { |_, hand_vals| hand_busted?(hand_vals) }
                      .reject { |_, hand_vals| hand_blackjack?(hand_vals) }.keys
  end

  def dealer_remaining?
    dealer_val = dealer_hand_value
    !hand_busted?(dealer_val) && !hand_blackjack?(dealer_val)
  end

  private

  def evaluate_hand(cards)
    permutes = [[]]
    cards.each do |card|
      case card.rank
      when 1
        p1 = permutes.map { |p| p + [1] }
        p11 = permutes.map { |p| p + [11] }
        permutes = p1 + p11
      when 11..13
        permutes = permutes.map { |p| p + [10] }
      else
        permutes = permutes.map { |p| p + [card.rank] }
      end
    end
    permutes.map(&:sum).uniq
  end

  def hand_blackjack?(hand_vals)
    hand_vals.include?(BLACKJACK)
  end

  def hand_busted?(hand_vals)
    hand_vals.all? { |val| val > BLACKJACK }
  end

  def best_hand_value(hand_vals)
    hand_busted?(hand_vals) ? hand_vals.min : hand_vals.reject { |val| val > BLACKJACK }.max
  end
end
