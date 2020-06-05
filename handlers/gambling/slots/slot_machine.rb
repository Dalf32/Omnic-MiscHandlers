# SlotMachine
#
# AUTHOR::  Kyle Mullins

class SlotMachine
  def initialize(symbols, paytable)
    @symbols = symbols
    @paytable = paytable
  end

  def spin
    symbol_count = @symbols.count
    (1..3).map { rand(1..symbol_count) }
  end

  def payout(reels)
    payout = @paytable.fetch(reels, 0)
    return payout unless payout.zero?

    reels.map { |symbol| symbol * (reels.count(symbol) - 1) }.max / 2.0
  end

  def format_reels(reels)
    reels.map { |reel| @symbols[reel - 1] }.join(' | ')
  end

  def symbols_str
    @symbols.map.with_index { |sym, i| "#{sym} | #{i + 1}" }.join("\n")
  end

  def paytable_str
    pay_str = @paytable.to_a
                       .map { |k, v| "#{format_reels(k)} = x#{v}" }.join("\n")
    pay_str += "\nAny 3 matching symbols not in the above table have a " \
               "payout equal to their rank.\n"
    pay_str + 'Any 2 matching symbols have a payout equal to half their rank.'
  end
end
