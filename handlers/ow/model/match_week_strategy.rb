# match_week_strategy.rb
#
# AUTHOR::  Kyle Mullins

class BaseWeekStrategy
  def add_matches(matches, embed)

    formatted_matches = matches.map do |match|
      if match.in_progress?
        "**>>**  #{match.to_s_with_result}  **<<**"
      else
        match.to_s
      end
    end

    embed.add_field(name: 'Matches',
                    value: formatted_matches.join("\n"))
  end

  def count_matches(matches)
    matches.count
  end
end

class GroupByDaysStrategy < BaseWeekStrategy
  def add_matches(matches, embed)
    match_count = 0

    match_days(matches).each_with_index do |day_matches, day|
      formatted_matches = day_matches.map do |match|
        if match.in_progress?
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

  def match_days(matches)
    matches.chunk_while { |m1, m2| m1.followed_by?(m2) }
  end
end

class GroupByRegionStrategy < BaseWeekStrategy
  def initialize(regions)
    @regions = regions
  end

  def add_matches(matches, embed)
    match_count = 0
    region_counts = Hash.new(0)

    regions(matches).each_with_index do |region_matches|
      formatted_matches = region_matches.map do |match|
        if match.in_progress?
          "**>>**  #{match.to_s_with_result}  **<<**"
        else
          match.to_s
        end
      end

      match_count += region_matches.count
      formatted_matches += ['-'] unless match_count == matches.count

      region = find_region(region_matches.first.tournament)
      region_counts[region.id] += 1

      embed.add_field(name: "#{region.abbreviation} Day #{region_counts[region.id]}",
                      value: formatted_matches.join("\n"))
    end
  end

  private

  def regions(matches)
    matches.chunk_while { |m1, m2| m1.tournament == m2.tournament }
  end

  def find_region(tournament_id)
    @regions.find { |region| region.tournament_id == tournament_id.to_i }
  end
end

class FilterByRegionStrategy < BaseWeekStrategy
  def initialize(region)
    @region = region
  end

  def add_matches(matches, embed)
    match_count = 0
    filtered_matches = filter_by_region(matches)

    match_days(filtered_matches).each_with_index do |day_matches, day|
      formatted_matches = day_matches.map do |match|
        if match.in_progress?
          "**>>**  #{match.to_s_with_result}  **<<**"
        else
          match.to_s
        end
      end

      match_count += day_matches.count
      formatted_matches += ['-'] unless match_count == filtered_matches.count

      embed.add_field(name: "#{@region.abbreviation} Day #{day + 1}",
                      value: formatted_matches.join("\n"))
    end
  end

  def count_matches(matches)
    filter_by_region(matches).count
  end

  private

  def filter_by_region(matches)
    matches.find_all { |match| match.tournament.to_i == @region.tournament_id }
  end

  def match_days(matches)
    matches.chunk_while { |m1, m2| m1.starts_near?(m2) }
  end
end
