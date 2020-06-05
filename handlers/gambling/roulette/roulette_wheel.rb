# RouletteWheel
#
# AUTHOR::  Kyle Mullins

require_relative 'roulette_bet'

class RouletteWheel
  def initialize
    @wheel = build_wheel
  end

  def spin
    @wheel[rand(1000) % @wheel.count]
  end

  def paytable_str
    RouletteBet.bets.reject { |bet| bet == InvalidBet }.map(&:paytable_str).join("\n")
  end

  private

  def build_wheel
    [
        Pocket.new('0', 'green'), Pocket.new('28', 'black'),
        Pocket.new('9', 'red'), Pocket.new('26', 'black'),
        Pocket.new('30', 'red'), Pocket.new('11', 'black'),
        Pocket.new('7', 'red'), Pocket.new('20', 'black'),
        Pocket.new('32', 'red'), Pocket.new('17', 'black'),
        Pocket.new('5', 'red'), Pocket.new('22', 'black'),
        Pocket.new('34', 'red'), Pocket.new('15', 'black'),
        Pocket.new('3', 'red'), Pocket.new('24', 'black'),
        Pocket.new('36', 'red'), Pocket.new('13', 'black'),
        Pocket.new('1', 'red'), Pocket.new('00', 'green'),
        Pocket.new('27', 'red'), Pocket.new('10', 'black'),
        Pocket.new('25', 'red'), Pocket.new('29', 'black'),
        Pocket.new('12', 'red'), Pocket.new('8', 'black'),
        Pocket.new('19', 'red'), Pocket.new('31', 'black'),
        Pocket.new('18', 'red'), Pocket.new('6', 'black'),
        Pocket.new('21', 'red'), Pocket.new('33', 'black'),
        Pocket.new('16', 'red'), Pocket.new('4', 'black'),
        Pocket.new('23', 'red'), Pocket.new('35', 'black'),
        Pocket.new('14', 'red'), Pocket.new('2', 'black')
    ]
  end
end

class Pocket
  attr_reader :number, :color

  def initialize(number, color)
    @number = number
    @color = color
  end

  def to_s
    "#{@color.capitalize} #{@number}"
  end
end
