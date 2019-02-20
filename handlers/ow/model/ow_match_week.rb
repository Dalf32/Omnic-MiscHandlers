# ow_match_week.rb
#
# AUTHOR::  Kyle Mullins

require 'date'
require_relative 'identifiable'
require_relative 'has_season'

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
    DateTime.now.between?(@start_date, @end_date)
  end

  def upcoming?
    DateTime.now < @start_date
  end

  def fill_embed(embed)
    date_mask = '%a, %d %b %Y'
    found_next_match = false
    match_count = 0

    embed.description = "#{@start_date.strftime(date_mask)} - #{@end_date.strftime(date_mask)}"
    add_event_to_embed(embed)
    match_days.each_with_index do |day_matches, day|
      formatted_matches = day_matches.map do |match|
        if !match.complete? && !found_next_match
          found_next_match = true
          "**>>**  #{match.to_s_with_result}  **<<**"
        else
          match.to_s
        end
      end

      match_count += day_matches.count
      formatted_matches += ['-'] unless match_count == matches.count

      embed.add_field(name: "Day #{day + 1}",
                      value: formatted_matches.join("\n"))
    end
  end

  private

  def add_event_to_embed(embed)
    return if @events.empty?

    embed.description += "\n#{'-' * 20}\n#{@events.first.embed_str}"
    embed.image = { url: @events.first.image }
  end

  def match_days
    @matches.chunk_while { |m1, m2| m1.followed_by?(m2) }
  end
end
