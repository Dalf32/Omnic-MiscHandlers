# gambling_handler.rb
#
# AUTHOR::  Kyle Mullins

require 'redis-objects'

class GamblingHandler < CommandHandler
  feature :gambling, default_enabled: false,
                     description: ''

  command(:money, :show_money)
    .feature(:gambling).max_args(0).usage('money').pm_enabled(false)
    .description('')

  command(:slotspar, :calc_slots_par)
    .feature(:gambling).args_range(0, 2).owner_only(true)
    .usage('slotspar [num_runs] [wager_amt]').description('')

  command(:slots, :play_slots)
    .feature(:gambling).args_range(1, 1).usage('slots <wager>')
    .pm_enabled(false).description('')

  command(:slotspaytable, :show_paytable)
    .feature(:gambling).max_args(0).usage('slotspaytable')
    .description('')

  command(:slotsymbols, :show_symbols)
    .feature(:gambling).max_args(0).usage('slotsymbols')
    .description('')

  def config_name
    :gambling
  end

  def redis_name
    :gambling
  end

  def show_money(event)
    ensure_funds(event.message)
    "You have $#{user_funds} and are rank #{user_rank_str} on the leaderboard!"
  end

  def calc_slots_par(_event, num_runs = 1_000_000, wager_amt = 5)
    winnings = 0.0
    wager_amt = wager_amt.to_i

    num_runs.to_i.times do
      payout = lookup_payout(spin_slots)
      winnings += payout * wager_amt
    end

    "PAR: #{(winnings / (wager_amt * num_runs.to_i)) * 100.0}%"
  end

  def play_slots(event, wager)
    return 'Invalid wager.' if wager.casecmp('all').zero? || !wager.to_i.positive?

    ensure_funds(event.message)
    wager_amt = wager.casecmp('all').zero? ? user_funds : wager.to_i
    return "You don't have enough money for that!" if wager_amt > user_funds

    reels = spin_slots
    payout = lookup_payout(reels)
    update_funds(wager_amt, payout)

    "You spun #{format_reels(reels)} and #{payout_str(payout, wager_amt)}"
  end

  def show_paytable(_event)
    pay_str = config.slots.paytable.to_a
                    .map { |k, v| "#{format_reels(k)} = x#{v}" }.join("\n")
    pay_str += "\nAny 3 matching symbols not in the above table have a " \
               "payout equal to their rank.\n"
    pay_str + 'Any 2 matching symbols have a payout equal to half their rank.'
  end

  def show_symbols(_event)
    config.slots.symbols.map
          .with_index { |sym, i| "#{sym} | #{i + 1}" }.join("\n")
  end

  private

  def spin_slots
    symbol_count = config.slots.symbols.count
    (1..3).map { rand(1..symbol_count) }
  end

  def lookup_payout(reels)
    payout = config.slots.paytable.fetch(reels, 0)
    return payout unless payout.zero?

    reels.map { |symbol| symbol * (reels.count(symbol) - 1) }.max / 2.0
  end

  def format_reels(reels)
    reels.map { |reel| config.slots.symbols[reel - 1] }.join(' | ')
  end

  def payout_str(payout, wager)
    win_amt = (wager * payout).to_i

    case payout
    when 0
      "*lost* your $#{wager}!"
    when 1
      "**won back** your $#{wager}!"
    when 0..1
      "*only lost* $#{wager - win_amt}!"
    else
      "**won** $#{win_amt}!"
    end
  end

  def funds_set
    @funds_set ||= Redis::SortedSet.new([server_redis.namespace, 'funds'])
  end

  def user_funds
    funds_set[@user.id].to_i
  end

  def update_funds(wager, payout)
    win_amt = (wager * payout).to_i
    funds_set[@user.id] += win_amt - wager
  end

  def user_rank_str
    total_users = funds_set.count
    user_rank = total_users - funds_set.rank(@user.id)
    "#{user_rank}/#{total_users}"
  end

  def ensure_funds(message)
    return if funds_set.member?(message.author.id)

    funds_set[message.author.id] = config.slots.start_funds
    message.reply("#{message.author.mention} you've been granted $#{config.slots.start_funds} to start off, don't lose it all too quick!")
  end
end
