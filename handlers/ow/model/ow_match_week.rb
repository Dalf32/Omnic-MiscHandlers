# ow_match_week.rb
#
# AUTHOR::  Kyle Mullins

require 'date'
require_relative 'identifiable'
require_relative 'has_season'
require_relative 'match_week_strategy'

class OwMatchWeek
  include Identifiable
  include HasSeason

  attr_accessor :matches, :events

  def dates(start_date:, end_date:)
    @start_date = start_date
    @end_date = end_date
    self
  end

  def in_progress?
    DateTime.now.between?(start_date, end_date)
  end

  def upcoming?
    DateTime.now < start_date
  end

  def fill_embed(embed, match_strategy: GroupByDaysStrategy.new)
    date_mask = '%a, %d %b %Y'

    embed.description = "#{start_date.strftime(date_mask)} - #{end_date.strftime(date_mask)}"
    add_event_to_embed(embed)
    match_strategy.add_matches(@matches, embed)
  end

  private

  def start_date
    return @start_date unless @start_date.nil?

    @matches.first.start_date
  end

  def end_date
    return @end_date unless @end_date.nil?

    @matches.last.end_date
  end

  def add_event_to_embed(embed)
    return if @events.nil? || @events.empty?

    embed.description += "\n#{'-' * 20}\n#{@events.first.embed_str}"
    embed.image = { url: @events.first.image }
  end
end
