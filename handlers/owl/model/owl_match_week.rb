# owl_match_week.rb
#
# AUTHOR::  Kyle Mullins

require 'date'

class OwlMatchWeek
  attr_reader :name
  attr_accessor :matches

  def initialize(id:, name:)
    @id = id
    @name = name
  end

  def dates(start_date:, end_date:)
    @start_date = start_date
    @end_date = end_date
    self
  end

  def in_progress?
    DateTime.now.between?(@start_date, @end_date)
  end

  def fill_embed(embed)
    date_mask = '%a, %d %b %Y'
    found_next_match = false

    embed.description = "#{@start_date.strftime(date_mask)} - #{@end_date.strftime(date_mask)}"
    matches.each_slice(3).with_index do |day_matches, day|
      formatted_matches = day_matches.map do |match|
        if !match.complete? && !found_next_match
          found_next_match = true
          "**>>**  #{match.to_s_with_result}  **<<**"
        else
          match.to_s
        end
      end

      formatted_matches += ['-'] unless (day + 1) * 3 == matches.count

      embed.add_field(name: "Day #{day + 1}",
                      value: formatted_matches.join("\n"))
    end
  end
end
