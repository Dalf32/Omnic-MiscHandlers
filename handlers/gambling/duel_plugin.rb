# DuelPlugin
#
# AUTHOR::  Kyle Mullins

class DuelPlugin < HandlerPlugin
  include GamblingHelper

  def self.plugin_target
    GamblingHandler
  end

  command(:duel, :start_duel)
    .feature(:gambling).args_range(2, 2).usage('duel <opponent> <wager>')
    .pm_enabled(false).description('Challenges the given player to a duel. Should they accept, both users put up the wagered amount and the winner claims the sum!')

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

  private

  def find_user_for_duel(opponent)
    found_user = find_user(opponent)
    return found_user if found_user.failure?

    found_user.error = 'You cannot challenge yourself.' if found_user.value.id == @user.id
    found_user.error = 'Bots cannot gamble!' if found_user.value.bot_account?
    found_user
  end

  def wager_for_duel(wager, opp_user)
    result = wager_for_gambling(wager)
    return result if result.failure?

    opp_funds = user_funds(opp_user.id)
    result.error = 'Your opponent does not have sufficient funds.' if result.value > opp_funds
    result.error = "Amount too small for your opponent's current funds." if opp_funds.to_f == opp_funds.to_f - result.value
    result
  end

  def challenge_duel(message, opp_user, wager_amt)
    message.reply("#{opp_user.mention}, #{@user.display_name} has challenged you to a duel for #{wager_amt.format_currency}! Do you accept? [Y/N]")
    answer = opp_user.await!(timeout: 120, start_with: /yes|no|[yn]$/i)&.text
    is_declined = answer.nil? || %w[n no].include?(answer.downcase)
    return "#{@user.mention}, your opponent declined the challenge." if is_declined

    message.reply('Challenge accepted!')
    duel(opp_user, wager_amt)
  end

  def duel(opponent, wager)
    my_rolls = roll(3, 6)
    opp_rolls = roll(3, 6)
    duel_str = "You each roll 3d6...\n"
    duel_str += "#{format_rolls(@user, my_rolls)}, #{format_rolls(opponent, opp_rolls)}"

    duel_str + case my_rolls.sum <=> opp_rolls.sum
               when 1
                 complete_duel(wager, @user, opponent)
               when -1
                 complete_duel(wager, opponent, @user)
               else
                 "\nThe duel was a draw! Money has been returned."
               end
  end

  def roll(num_dice, dice_rank)
    Array.new(num_dice) { rand(1..dice_rank) }
  end

  def format_rolls(user, rolls)
    "#{user.display_name} rolled [#{rolls.join(' + ')}] = #{rolls.sum}"
  end

  def complete_duel(wager, winner, loser)
    update_funds(wager, 2, winner.id)
    update_funds(wager, 0, loser.id)
    "\n#{winner.display_name} **wins** #{(wager * 2).format_currency}!"
  end
end
