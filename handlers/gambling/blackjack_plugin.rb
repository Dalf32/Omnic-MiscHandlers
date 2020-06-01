# BlackjackPlugin
#
# AUTHOR::  Kyle Mullins

require_relative 'card_deck'
require_relative 'blackjack_bets_set'
require_relative 'blackjack_table'

module BlackjackPlugin
  def self.included(klass)
    klass.command(:blackjack, :start_blackjack)
      .feature(:gambling).no_args.usage('blackjack')
      .description('Starts a game of blackjack.')

    klass.command(:blackjackbet, :enter_blackjack_bet)
      .feature(:gambling).args_range(1, 1).usage('blackjackbet <wager>')
      .description('Enters your bet for an active blackjack game.')

    klass.command(:blackjackpaytable, :show_blackjack_paytable)
      .feature(:gambling).no_args.usage('blackjackpaytable')
      .description('Shows the paytable for the blackjack game.')
  end

  def start_blackjack(event)
    return 'A blackjack game is already in progress.' if server_redis.exists(BLACKJACK_KEY)

    event.message.reply('A game of blackjack is about to start, get your bets in!')
    server_redis.set(BLACKJACK_KEY, 0)

    unless @user.await!(timeout: 45, start_with: /cancel$/i)&.text.nil?
      end_game
      return 'The game has been cancelled.'
    end

    event.message.reply('**The deck is being shuffled, last call for bets!**')
    sleep(30)

    server_redis.set(BLACKJACK_KEY, 1)
    server_redis.expire(BLACKJACK_KEY, 60 * 10) # Set the key to expire in case of error
    ret_str = blackjack_bets.empty? ? 'No bets were placed.' : play_game(event.message)
    end_game
    ret_str
  end

  def enter_blackjack_bet(event, wager)
    return 'There are no active blackjack games.' unless server_redis.exists(BLACKJACK_KEY)
    return 'You have already bet on this game.' if blackjack_bets.has_bet?(@user.id)
    return 'The game has already started.' if server_redis.get(BLACKJACK_KEY) == '1'

    ensure_funds(event.message)
    lock_funds(@user.id) do
      wager_result = wager_for_gambling(wager)
      wager_amt = wager_result.value
      return wager_result.error if wager_result.failure?

      funds_set[@user.id] -= wager_amt
      update_house_funds(wager_amt)
      blackjack_bets.add_bet(@user.id, wager_amt)

      "#{wager_amt.format_currency} bet entered for #{@user.display_name}"
    end
  end

  def show_blackjack_paytable(_event)
    "Natural Blackjack (Ace + 10-card) = x1.5\nBeating dealer = x1\nLosing to dealer = x0"
  end

  private

  BLACKJACK_KEY = 'blackjack'

  def blackjack_bets
    @blackjack_bets ||= BlackjackBetsSet.new(server_redis)
  end

  def payouts
    @payouts ||= {}
  end

  def show_card(card)
    card.format(config.blackjack.ranks, config.blackjack.suits)
  end

  def play_game(message)
    game_table = BlackjackTable.new(
        all_players, CardDeck.new(num_decks: config.blackjack.num_decks))

    # Initial deal
    game_table.shuffle
    player_cards = game_table.deal_cards(all_players, 2)
    dealer_cards = game_table.dealer_draw(2)
    message.reply(initial_deal_str(player_cards, dealer_cards))

    # Check for natural 21s
    players_with_blackjack = game_table.players_with_blackjack
    if game_table.dealer_blackjack?
      players_with_blackjack.each { |player| payouts[player] = 1 }
      (all_players - players_with_blackjack).each { |player| payouts[player] = 0 }
    else
      players_with_blackjack.each { |player| payouts[player] = 2.5 }
    end

    blackjack_str = natural_blackjack_str(players_with_blackjack, game_table)
    message.reply(blackjack_str) unless blackjack_str.empty?
    return payout_players if game_table.dealer_blackjack?

    # Resolve remaining players
    game_table.remaining_players.each { |player| play_hand(message, game_table, player) }

    # Resolve dealer
    game_finish_str = ''
    game_finish_str += play_dealer_hand(game_table) if game_table.dealer_remaining?
    game_finish_str += final_hands_str(game_table)

    # Determine payouts
    determine_payouts(game_table)
    game_finish_str + payout_players
  end

  def end_game
    server_redis.del(BLACKJACK_KEY)
    blackjack_bets.clear_bets
  end

  def all_players
    blackjack_bets.players.map { |user_id| @server.member(user_id) }
  end

  def initial_deal_str(player_cards, dealer_cards)
    deal_str = "The Dealer begins dealing cards...\n"
    deal_str += player_cards.map do |player, cards|
      cards_str = cards.map { |card| show_card(card) }.join(' and ')
      "#{player.display_name} is dealt: #{cards_str}"
    end.join("\n")
    deal_str + "\nThe Dealer is dealt: #{show_card(dealer_cards.first)} and one card face down"
  end

  def natural_blackjack_str(players_with_blackjack, game_table)
    has_have_str = players_with_blackjack.count > 1 ? 'have' : 'has'
    also_str = ''
    blackjack_str = ''

    if game_table.dealer_blackjack?
      also_str = ' also'
      blackjack_str = "The Dealer has Blackjack! #{print_hand(game_table.dealer_hand)}\n"
    end

    if players_with_blackjack.any?
      blackjack_str += players_with_blackjack.map(&:display_name).join(', ')
      blackjack_str += "#{also_str} #{has_have_str} Blackjack!"
    end

    blackjack_str
  end

  def play_hand(message, game_table, player)
    loop do
      hand_value = game_table.player_best_hand_value(player)
      message.reply("#{player.mention} you have #{hand_value}, [H]it or [S]tand?")

      action_regex = /([hs]|hit|stand|stay)$/i
      action = player.await!(timeout: 60, start_with: action_regex)&.text || 's'

      hand_finished, action_msg = *handle_action(game_table, player, action)
      message.reply(action_msg)
      break if hand_finished
    end
  end

  def handle_action(game_table, player, action)
    case action
    when /h|hit/i
      card = game_table.deal_cards_to(player, 1).first
      msg = "#{player.display_name} is dealt #{show_card(card)}..."
      if game_table.player_blackjack?(player)
        [true, msg + " 21!"]
      elsif game_table.player_busted?(player)
        [true, msg + " You bust!"]
      else
        [false, msg]
      end
    when /s|stand|stay/i
      hand_value = game_table.player_best_hand_value(player)
      [true, "#{player.display_name} chooses to stay at #{hand_value}."]
    else
      'Unsupported action'
    end
  end

  def play_dealer_hand(game_table)
    dealer_text = "The Dealer turns their face down card up, they have: "
    dealer_text += print_hand(game_table.dealer_hand)

    loop do
      dealer_val = game_table.dealer_best_hand_value

      if game_table.dealer_busted?
        dealer_text += "... Bust!\n"
        break
      elsif game_table.dealer_blackjack?
        dealer_text += "... 21!\n"
        break
      elsif dealer_val >= 17
        dealer_text += "\nDealer stays at #{dealer_val}\n"
        break
      else
        card = game_table.dealer_draw(1).first
        dealer_text += "\nHit: #{show_card(card)}"
      end
    end

    dealer_text
  end

  def determine_payouts(game_table)
    dealer_value = game_table.dealer_best_hand_value
    did_dealer_bust = game_table.dealer_busted?
    (all_players - payouts.keys).each do |player|
      if game_table.player_busted?(player)
        payouts[player] = 0
      elsif did_dealer_bust
        payouts[player] = 2
      else
        player_value = game_table.player_best_hand_value(player)
        payouts[player] = (player_value <=> dealer_value) + 1
      end
    end
  end

  def payout_players
    payouts.map do |player, payout|
      wager = blackjack_bets[player.id]
      win_amt = (wager * payout).to_i
      lock_funds(player.id) { funds_set[player.id] += win_amt }
      update_house_funds(-win_amt)
      "#{player.mention} you #{payout_str(payout, wager)}"
    end.join("\n")
  end

  def print_hand(hand)
    hand.evaluate do |cards|
      cards[0..-2].map { |card| show_card(card) }.join(', ') +
          " and #{show_card(cards.last)}"
    end
  end

  def final_hands_str(game_table)
    hands_str = "Dealer: #{game_table.dealer_best_hand_value}\n"
    hands_str + game_table.player_best_hand_values.map do |player, hand_val|
      "#{player.display_name}: #{hand_val}"
    end.join("\n") + "\n"
  end
end
