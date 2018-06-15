# owl_stat.rb
#
# AUTHOR::  Kyle Mullins

require 'chronic_duration'

class OwlStat
  def initialize(name, value, rank: nil)
    @name = name
    @value = value
    @rank = rank
  end

  def format_table_row
    format(' %-18s|  %-12s|   %s', @name, value_str, @rank)
  end

  def to_s
    "#{@name} = #{value_str}"
  end

  private

  def value_str
    if @name.downcase.include?('time')
      ChronicDuration.output(@value.truncate, format: :short)
    else
      format('%.2f', @value)
    end
  end
end
