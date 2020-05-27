# gambling_handler.rb
#
# AUTHOR::  Kyle Mullins

require 'tabulo'
require_relative 'gambling/funds_set'
require_relative 'gambling/duel_plugin'
require_relative 'gambling/slots_plugin'
require_relative 'gambling/roulette_plugin'

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

  include DuelPlugin
  include SlotsPlugin
  include RoulettePlugin

  def config_name
    :gambling
  end

  def redis_name
    :gambling
  end

  def show_money(event, player = nil)
    return show_money_other_user(event.message, player) unless player.nil?

    ensure_funds(event.message)
    "#{@user.display_name}, you have #{user_funds.format_currency} and are rank #{user_rank_str} on the leaderboard!"
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
    "#{@user.display_name}, you've claimed your daily bonus of #{claim_amt.format_currency}#{streak_str}!"
  end

  def show_money_leaders(_event)
    table = Tabulo::Table.new(funds_set.leaders, border: :modern) do |table|
      table.add_column('Rank', formatter: -> (r) { '%03i' % r }) do |leader|
        user_rank(leader)
      end
      table.add_column('Name') { |leader| @server.member(leader).display_name }
      table.add_column('Money', formatter: :format_currency.to_proc) do |leader|
        user_funds(leader)
      end
    end

    "```#{table.pack}```"
  end

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

  def payout_str(payout, wager)
    win_amt = (wager * payout).to_i

    case payout
    when 0
      "*lost* your #{wager.format_currency}!"
    when 1
      "**won back** your #{wager.format_currency}!"
    when 0..1
      "*only lost* #{(wager - win_amt).format_currency}!"
    else
      if win_amt == wager
        "**won back** your #{wager.format_currency}!"
      else
        "**won** #{win_amt.format_currency}!"
      end
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
    funds_str = config.start_funds.format_currency
    message.reply("#{user.mention} you've been granted #{funds_str} to start off, don't lose it all too quick!")
  end

  def claim_key
    "claims:#{@user.id}"
  end

  def show_money_other_user(message, player_str)
    found_user = find_user(player_str)
    return found_user.error if found_user.failure?

    user = found_user.value
    return 'Bots cannot gamble!' if user.bot_account?

    ensure_funds(message)
    user_funds_str = user_funds(user.id).format_currency
    "#{user.display_name} has #{user_funds_str} and is rank #{user_rank_str(user.id)} on the leaderboard!"
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
end
