# gambling_handler.rb
#
# AUTHOR::  Kyle Mullins

require 'tabulo'
require_relative 'gambling/gambling_helper'

class GamblingHandler < CommandHandler
  include GamblingHelper

  feature :gambling, default_enabled: false,
                     description: 'Allows users to wager currency in games of chance.'

  command(:money, :show_money)
    .feature(:gambling).args_range(0, 1).usage('money [user]').pm_enabled(false)
    .description('Shows how much money you have and your rank on the leaderboard.')

  command(:dailymoney, :claim_daily_money)
    .feature(:gambling).no_args.usage('dailymoney').pm_enabled(false)
    .description('Claims daily money, building up a streak grants bonus money!')

  command(:moneyleaders, :show_money_leaders)
    .feature(:gambling).no_args.usage('moneyleaders').pm_enabled(false)
    .description('Shows the top ranking players.')

  command(:housemoney, :show_house_money)
    .feature(:gambling).no_args.usage('housemoney').pm_enabled(false)
    .description('Shows the amount of money the House has earned.')

  command(:addmoney, :add_money)
    .feature(:gambling).args_range(2, 2).usage('addmoney <user> <amount>')
    .pm_enabled(false).permissions(:manage_server)
    .description('Gives some of your money to another player.')

  command(:givemoney, :give_money)
    .feature(:gambling).args_range(2, 2).usage('givemoney <user> <amount>').pm_enabled(false)
    .description('Gives some of your money to another player.')

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
    claim_amt = daily_money_claim_amt(streak)
    lock_funds(@user.id) { funds_set[@user.id] += claim_amt }

    streak_str = daily_money_streak_str(streak)
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

  def show_house_money(_event)
    "The House has #{house_funds.format_currency} in the bank."
  end

  def add_money(event, player, amount)
    found_user = find_user(player)
    return found_user.error if found_user.failure?

    user = found_user.value
    return 'Bots cannot gamble!' if user.bot_account?

    ensure_funds(event.message, user)
    add_amount = amount_from_str(amount)
    return 'Invalid amount.' if add_amount.zero?

    lock_funds(user.id) { funds_set[user.id] += add_amount }
    "#{add_amount.format_currency} has been added to #{user.display_name}'s account."
  end

  def give_money(event, player, amount)
    ensure_funds(event.message)
    found_user = find_user(player)
    return found_user.error if found_user.failure?

    recv_user = found_user.value
    return 'Bots cannot gamble!' if recv_user.bot_account?
    return 'You cannot give money to yourself!' if recv_user.id == @user.id

    ensure_funds(event.message, recv_user)
    give_amt_result = wager_for_gambling(amount)
    give_amount = give_amt_result.value
    return give_amt_result.error if give_amt_result.failure?

    lock_funds(@user.id) do
      lock_funds(recv_user.id) do
        funds_set[@user.id] -= give_amount
        funds_set[recv_user] += give_amount
      end
    end

    "#{give_amount.format_currency} has been transferred from #{@user.display_name} to #{recv_user.display_name}."
  end

  private

  ONE_DAY = 24 * 60 * 60 unless defined? ONE_DAY

  def user_rank(user_id = @user.id)
    funds_set.rank(user_id)
  end

  def user_rank_str(user_id = @user.id)
    funds_set.rank_str(user_id)
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

  def daily_money_claim_amt(streak)
    claim_amt = 50 + (25 * [18, streak - 1].min)
    claim_amt *= 10 * (streak / 365) if (streak % 365).zero?

    claim_amt
  end

  def daily_money_streak_str(streak)
    years = streak / 365
    days = streak % 365

    case
    when years.positive? && days.zero?
      ". **Congrats!** You're on a #{years} year streak"
    when years.positive?
      ". You're on a #{years} year #{days} day streak"
    when days.positive?
      ". You're on a #{days} day streak"
    else
      ''
    end
  end
end
