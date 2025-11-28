# GamblingHelper
#
# AUTHOR::  Kyle Mullins

require_relative 'funds_set'

module GamblingHelper
  HOUSE_MONEY_KEY = 'house' unless defined? HOUSE_MONEY_KEY

  def lock_funds(user_id, server_id = @server.id)
    retval = nil

    Omnic.mutex("gambling:#{server_id}:#{user_id}").tap do |mutex|
      mutex.acquire
      retval = yield
    ensure
      mutex.release
    end

    retval
  end

  def funds_set(redis = server_redis)
    @funds_set ||= FundsSet.new(redis)
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

  def ensure_funds(message, user = @user)
    return if funds_set.include?(user.id)

    lock_funds(@user.id) { funds_set[user.id] = config.start_funds }
    funds_str = config.start_funds.format_currency
    message.reply("#{user.mention} you've been granted #{funds_str} to start off, don't lose it all too quick!")
  end

  def amount_from_str(amount)
    amount = amount.gsub(',', '')

    if amount =~ /\A\d+(\.\d+)?([kmbtq]|e\d+)?\Z/i
      amt_num = amount.to_f
      amt_num *= 1_000 if amount.downcase.end_with?('k')
      amt_num *= 1_000_000 if amount.downcase.end_with?('m')
      amt_num *= 1_000_000_000 if amount.downcase.end_with?('b')
      amt_num *= 1_000_000_000_000 if amount.downcase.end_with?('t')
      amt_num *= 1_000_000_000_000_000 if amount.downcase.end_with?('q')
      return amt_num.to_i
    end

    0
  end

  def wager_from_str(wager)
    return 0 if wager.nil? || wager.empty?
    return user_funds if wager.casecmp?('all')
    return user_funds / 2 if wager.casecmp?('half')
    return rand(user_funds) + 1 if wager.casecmp?('random')

    amount_from_str(wager)
  end

  def wager_for_gambling(wager)
    wager_amt = wager_from_str(wager)

    Result.new.tap do |result|
      result.error = "You don't have enough money for that!" if wager_amt > user_funds
      result.error = 'Amount too small for your current funds.' if user_funds.to_f == user_funds.to_f - wager_amt
      result.error = 'Invalid wager.' if wager_amt.zero?
      result.value = wager_amt
    end
  end

  def ensure_house_funds(server_id = @server.id)
    return if server_redis(server_id).exists?(HOUSE_MONEY_KEY)

    lock_funds(HOUSE_MONEY_KEY, server_id) { server_redis(server_id).set(HOUSE_MONEY_KEY, 0) }
  end

  def house_funds(server_id = @server.id)
    ensure_house_funds(server_id)
    server_redis(server_id).get(HOUSE_MONEY_KEY).to_i
  end

  def update_house_funds(amount, server_id = @server.id)
    ensure_house_funds(server_id)
    lock_funds(HOUSE_MONEY_KEY, server_id) do
      server_redis(server_id).set(HOUSE_MONEY_KEY, house_funds(server_id) + amount)
    end
  end
end
