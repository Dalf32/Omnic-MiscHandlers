# gambling_handler.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'gambling/funds_set'
require_relative 'gambling/slot_machine'
require_relative 'gambling/roulette_wheel'
require_relative 'gambling/roulette_bet'
require_relative 'gambling/roulette_bets_set'

class GamblingHandler < CommandHandler
  feature :gambling, default_enabled: false,
                     description: 'Allows users to wager currency in games of chance.'

  command(:money, :show_money)
    .feature(:gambling).args_range(0, 1).usage('money [user]').pm_enabled(false)
    .description('Shows how much money you have and your rank on the leaderboard.')

  command(:dailymoney, :claim_daily_money)
    .feature(:gambling).max_args(0).usage('dailymoney').pm_enabled(false)
    .description('Claims daily money, building up a streak grants bonus money!')

  command(:moneyleaders, :show_money_leaders)
    .feature(:gambling).max_args(0).usage('moneyleaders').pm_enabled(false)
    .description('Shows the top ranking players.')

  command(:slotspar, :calc_slots_par)
    .feature(:gambling).args_range(0, 2).owner_only(true)
    .usage('slotspar [num_runs] [wager_amt]')
    .description('Calculates the PAR for the slots game.')

  command(:slots, :play_slots)
    .feature(:gambling).args_range(1, 1).usage('slots <wager>')
    .pm_enabled(false).description('Bet some money and spin the slots for a chance to win big!')

  command(:slotspaytable, :show_slots_paytable)
    .feature(:gambling).max_args(0).usage('slotspaytable')
    .description('Shows the paytable for the slots game.')

  command(:slotsymbols, :show_symbols)
    .feature(:gambling).max_args(0).usage('slotsymbols')
    .description('Shows the possible symbols for the slots game.')

  command(:duel, :start_duel)
    .feature(:gambling).args_range(2, 2).usage('duel <opponent> <wager>')
    .pm_enabled(false).description('Challenges the given player to a duel. Should they accept, both users put up the wagered amount and the winner claims the sum!')

  command(:roulette, :start_roulette)
    .feature(:gambling).max_args(0).usage('roulette')
    .description('Starts a game of roulette.')

  command(:roulettebet, :enter_roulette_bet)
    .feature(:gambling).args_range(2, 2).usage('roulettebet <bet> <wager>')
    .description('Enters your bet for the active roulette game.')

  command(:roulettepaytable, :show_roulette_paytable)
    .feature(:gambling).max_args(0).usage('roulettepaytable')
    .description('Shows the paytable for the roulette game.')

  def config_name
    :gambling
  end

  def redis_name
    :gambling
  end

  def show_money(event, player = nil)
    return show_money_other_user(event.message, player) unless player.nil?

    ensure_funds(event.message)
    "#{@user.display_name}, you have $#{user_funds} and are rank #{user_rank_str} on the leaderboard!"
  end

  def claim_daily_money(event)
    ensure_funds(event.message)
    streak = 1

    if server_redis.exists(claim_key)
      streak = server_redis.get(claim_key).to_i + 1
      ttl = server_redis.ttl(claim_key)
      return 'You can only claim money once a day.' if ttl > ONE_DAY
    end

    server_redis.setex(claim_key, ONE_DAY * 2, streak)
    claim_amt = 50 + (25 * [18, streak - 1].min)
    lock_funds(@user.id) { funds_set[@user.id] += claim_amt }

    streak_str = streak > 1 ? ". You're on a #{streak} day streak" : ''
    "#{@user.display_name}, you've claimed your daily bonus of $#{claim_amt}#{streak_str}!"
  end

  def show_money_leaders(_event)
    leaders = money_leaders

    max_name_len = [*leaders.map { |usr| usr[:name].length }, 4].max
    max_money_len = [*leaders.map { |usr| usr[:funds].to_s.length }, 5].max + 1

    name_pad = (max_name_len / 2.0).ceil
    money_pad = (max_money_len / 2.0).ceil

    row_template = "%4s  |  %#{name_pad}s%-#{name_pad}s  |  %#{money_pad}s%-#{money_pad}s"
    header_str = format(row_template, 'Rank', 'Na', 'me', 'Mon', 'ey')
    div_str = format(row_template, '----', '--', '--', '---', '--')

    rows_str = leaders.map do |leader|
      name_split = leader[:name].chars.each_slice((leader[:name].length / 2.0).ceil).to_a
      money_split = leader[:funds].to_s.chars.each_slice((leader[:funds].to_s.length / 2.0).ceil).to_a

      format(row_template, format(' %03i', leader[:rank]),
             name_split[0].join, name_split[1..-1].flatten.join,
             '$' + money_split[0].join, money_split[1..-1].flatten.join)
    end

    "```#{header_str}\n#{div_str}\n#{rows_str.join("\n")}```"
  end

  def calc_slots_par(event, num_runs = 1_000_000, wager_amt = 5)
    event.channel.start_typing
    winnings = 0.0
    wager_amt = wager_amt.to_i

    num_runs.to_i.times do
      payout = slot_machine.payout(slot_machine.spin)
      winnings += payout * wager_amt
    end

    "PAR: #{(winnings / (wager_amt * num_runs.to_i)) * 100.0}%"
  end

  def play_slots(event, wager)
    ensure_funds(event.message)

    lock_funds(@user.id) do
      wager_result = wager_for_gambling(wager)
      wager_amt = wager_result.value
      return wager_result.error if wager_result.failure?

      reels = slot_machine.spin
      payout = slot_machine.payout(reels)
      update_funds(wager_amt, payout)

      "#{@user.display_name}, you spun #{slot_machine.format_reels(reels)} and #{payout_str(payout, wager_amt)}"
    end
  end

  def show_slots_paytable(_event)
    slot_machine.paytable_str
  end

  def show_symbols(_event)
    slot_machine.symbols_str
  end

  def start_duel(event, opponent, wager)
    ensure_funds(event.message)
    found_user = find_user_for_duel(opponent)
    opp_user = found_user.value
    return found_user.error if found_user.failure?

    ensure_funds(event.message, opp_user)

    lock_funds(@user.id) do
      lock_funds(opp_user.id) do
        wager_result = wager_for_duel(wager, opp_user)
        wager_amt = wager_result.value
        return wager_result.error if wager_result.failure?

        challenge_duel(event.message, opp_user, wager_amt)
      end
    end
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
        "#{user.mention} bet #{bet} and wins $#{bet.winnings}!"
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
      roulette_bets.add_bet(@user.id, bet.with_wager(wager_amt))
    end

    "Bet entered for #{@user.display_name}: #{bet}"
  end

  def show_roulette_paytable(_event)
    roulette_wheel.paytable_str
  end

  # TODO: Show wheel?

  private

  ONE_DAY = 24 * 60 * 60 unless defined? ONE_DAY

  def lock_funds(user_id)
    retval = nil

    Omnic.mutex("gambling:#{@server.id}:#{user_id}").tap do |mutex|
      mutex.acquire
      retval = yield
    ensure
      mutex.release
    end

    retval
  end

  def funds_set
    @funds_set ||= FundsSet.new(server_redis)
  end

  def slot_machine
    @slot_machine ||= SlotMachine.new(config.slots.symbols,
                                      config.slots.paytable)
  end

  def roulette_wheel
    @roulette_wheel ||= RouletteWheel.new
  end

  def roulette_bets
    @roulette_bets ||= RouletteBetsSet.new(server_redis)
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
      win_amt == wager ? "**won back** your $#{wager}!" : "**won** $#{win_amt}!"
    end
  end

  def user_funds(user_id = @user.id)
    funds_set[user_id]
  end

  def update_funds(wager, payout, user_id = @user.id)
    win_amt = (wager * payout).to_i
    funds_set[user_id] += win_amt - wager
  end

  def user_rank(user_id = @user.id)
    funds_set.rank(user_id)
  end

  def user_rank_str(user_id = @user.id)
    funds_set.rank_str(user_id)
  end

  def ensure_funds(message, user = @user)
    return if funds_set.include?(user.id)

    lock_funds(@user.id) { funds_set[user.id] = config.start_funds }
    message.reply("#{user.mention} you've been granted $#{config.start_funds} to start off, don't lose it all too quick!")
  end

  def claim_key
    "claims:#{@user.id}"
  end

  def duel(opponent, wager)
    my_rolls = roll(3, 6)
    opp_rolls = roll(3, 6)
    duel_str = "You each roll 3d6...\n"
    duel_str += "#{format_rolls(@user, my_rolls)}, #{format_rolls(opponent, opp_rolls)}"

    winner = @user
    loser = opponent

    if my_rolls.sum < opp_rolls.sum
      winner = opponent
      loser = @user
    end

    update_funds(wager, 2, winner.id)
    update_funds(wager, 0, loser.id)
    duel_str + "\n#{winner.display_name} **wins** $#{wager * 2}!"
  end

  def roll(num_dice, dice_rank)
    Array.new(num_dice) { rand(1..dice_rank) }
  end

  def format_rolls(user, rolls)
    "#{user.display_name} rolled [#{rolls.join(' + ')}] = #{rolls.sum}"
  end

  def show_money_other_user(message, player_str)
    found_user = find_user(player_str)
    return found_user.error if found_user.failure?

    user = found_user.value
    return 'Bots cannot gamble!' if user.bot_account?

    ensure_funds(message)
    "#{user.display_name} has $#{user_funds(user.id)} and is rank #{user_rank_str(user.id)} on the leaderboard!"
  end

  def find_user_for_duel(opponent)
    found_user = find_user(opponent)
    return found_user if found_user.failure?

    found_user.error = 'You cannot challenge yourself.' if found_user.value.id == @user.id
    found_user.error = 'Bots cannot gamble!' if found_user.value.bot_account?
    found_user
  end

  def wager_from_str(wager)
    return user_funds if wager.casecmp('all').zero?
    return user_funds / 2 if wager.casecmp('half').zero?
    return rand(user_funds) + 1 if wager.casecmp('random').zero?

    wager = wager.gsub(',', '')

    if wager =~ /\A\d+\.?\d*[km]?\Z/i
      wager_amt = wager.to_f
      wager_amt *= 1000 if wager.end_with?('k')
      wager_amt *= 1_000_000 if wager.end_with?('m')
      return wager_amt.to_i
    end

    0
  end

  def wager_for_gambling(wager)
    wager_amt = wager_from_str(wager)

    Result.new.tap do |result|
      result.error = 'Invalid wager.' if wager_amt.zero?
      result.error = "You don't have enough money for that!" if wager_amt > user_funds
      result.value = wager_amt
    end
  end

  def wager_for_duel(wager, opp_user)
    result = wager_for_gambling(wager)
    return result if result.failure?

    result.error = 'Your opponent does not have sufficient funds.' if result.value > user_funds(opp_user.id)
    result
  end

  def challenge_duel(message, opp_user, wager_amt)
    message.reply("#{opp_user.mention}, #{@user.display_name} has challenged you to a duel for $#{wager_amt}! Do you accept? [Y/N]")
    answer = opp_user.await!(timeout: 120, start_with: /yes|no|[yn]$/i)&.text
    is_declined = answer.nil? || %w[n no].include?(answer.downcase)
    return "#{@user.mention}, your opponent declined the challenge." if is_declined

    message.reply('Challenge accepted!')
    duel(opp_user, wager_amt)
  end

  def money_leaders
    funds_set.leaders.map do |user_id|
      {
          rank: user_rank(user_id), name: @server.member(user_id).display_name,
          funds: user_funds(user_id)
      }
    end
  end

  def end_roulette
    server_redis.del('roulette')
    roulette_bets.clear_bets
  end
end
