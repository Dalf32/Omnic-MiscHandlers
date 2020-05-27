# RoulettePlugin
#
# AUTHOR::  Kyle Mullins

require_relative 'roulette_wheel'
require_relative 'roulette_bet'
require_relative 'roulette_bets_set'

module RoulettePlugin
  def self.included(klass)
    klass.command(:roulette, :start_roulette)
      .feature(:gambling).max_args(0).usage('roulette')
      .description('Starts a game of roulette.')

    klass.command(:roulettebet, :enter_roulette_bet)
      .feature(:gambling).args_range(2, 2).usage('roulettebet <bet> <wager>')
      .description('Enters your bet for the active roulette game.')

    klass.command(:roulettepaytable, :show_roulette_paytable)
      .feature(:gambling).max_args(0).usage('roulettepaytable')
      .description('Shows the paytable for the roulette game.')
  end

  def start_roulette(event)
    return 'A roulette game is already in progress.' if server_redis.exists('roulette')

    event.message.reply('A game of roulette is about to start, get your bets in!')
    server_redis.set('roulette', 0)

    unless @user.await!(timeout: 90, start_with: /cancel$/i)&.text.nil?
      end_roulette
      return 'The game has been cancelled.'
    end

    event.message.reply('**The wheel has been spun, last call for bets!**')
    sleep(30)

    pocket = roulette_wheel.spin
    ret_str = "The ball lands on #{pocket}!\n"

    # TODO: Table: Player | Bet | Result (w/l + payout)
    ret_str += roulette_bets.all_bets.map do |user_id, bet|
      user = @server.member(user_id)
      if bet.win?(pocket)
        lock_funds(user.id) { funds_set[user.id] += bet.winnings }
        update_house_funds(-bet.winnings)
        "#{user.mention} bet #{bet} and wins #{bet.winnings.format_currency}!"
      else
        "#{user.mention} bet #{bet} and loses."
      end
    end.join("\n")

    end_roulette
    ret_str
  end

  def enter_roulette_bet(event, bet_str, wager)
    return 'There are no active roulette games.' unless server_redis.exists('roulette')
    return 'You have already bet on this game.' if roulette_bets.has_bet?(@user.id)

    ensure_funds(event.message)
    bet = RouletteBet.create(bet_str)
    return "Invalid bet: #{bet}" unless bet.valid?

    lock_funds(@user.id) do
      wager_result = wager_for_gambling(wager)
      wager_amt = wager_result.value
      return wager_result.error if wager_result.failure?

      funds_set[@user.id] -= wager_amt
      update_house_funds(wager_amt)
      roulette_bets.add_bet(@user.id, bet.with_wager(wager_amt))
    end

    "Bet entered for #{@user.display_name}: #{bet}"
  end

  def show_roulette_paytable(_event)
    roulette_wheel.paytable_str
  end

  # TODO: Show wheel?

  private

  def roulette_wheel
    @roulette_wheel ||= RouletteWheel.new
  end

  def roulette_bets
    @roulette_bets ||= RouletteBetsSet.new(server_redis)
  end

  def end_roulette
    server_redis.del('roulette')
    roulette_bets.clear_bets
  end
end
