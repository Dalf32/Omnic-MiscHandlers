# SlotsPlugin
#
# AUTHOR::  Kyle Mullins

require_relative 'slot_machine'

class SlotsPlugin < HandlerPlugin
  include GamblingHelper

  def self.plugin_target
    GamblingHandler
  end

  command(:slotspar, :calc_slots_par)
    .feature(:gambling).args_range(0, 2).owner_only(true)
    .usage('slotspar [num_runs] [wager_amt]')
    .description('Calculates the PAR for the slots game.')

  command(:slots, :play_slots)
    .feature(:gambling).args_range(1, 1).usage('slots <wager>')
    .pm_enabled(false).description('Bet some money and spin the slots for a chance to win big!')

  command(:slotspaytable, :show_slots_paytable)
    .feature(:gambling).no_args.usage('slotspaytable')
    .description('Shows the paytable for the slots game.')

  command(:slotsymbols, :show_symbols)
    .feature(:gambling).no_args.usage('slotsymbols')
    .description('Shows the possible symbols for the slots game.')

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
      update_house_funds(wager_amt - (wager_amt * payout).to_i)

      "#{@user.display_name}, you spun #{slot_machine.format_reels(reels)} and #{payout_str(payout, wager_amt)}"
    end
  end

  def show_slots_paytable(_event)
    slot_machine.paytable_str
  end

  def show_symbols(_event)
    slot_machine.symbols_str
  end

  private

  def slot_machine
    @slot_machine ||= SlotMachine.new(config.slots.symbols,
                                      config.slots.paytable)
  end
end
