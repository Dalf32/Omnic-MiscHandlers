# ow_match.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'has_status'

class OwMatch
  include HasStatus

  attr_reader :id
  attr_writer :games

  def initialize(id:)
    @id = id
  end

  def basic_info(state:, start_date:, end_date:)
    @state = state
    @start_date = start_date
    @end_date = end_date
    self
  end

  def teams(away:, home:)
    @away_team = away
    @home_team = home
    self
  end

  def result(away_wins:, home_wins:, draws:, winner:)
    @away_wins = away_wins
    @home_wins = home_wins
    @draws = draws
    @winner = @away_team.eql?(winner) ? @away_team : @home_team unless winner.nil?
    self
  end

  def followed_by?(other_match)
    (other_match.start_date - @end_date) <= (2 / 24.0) # Two hour difference
  end

  def fill_live_embed(embed, maps)
    embed.add_field(name: 'Map', value: "#{format_maps(maps)}\n-",
                    inline: true)

    map_scores = format_map_scores
    embed.add_field(name: @away_team.abbrev,
                    value: "#{map_scores.map(&:first).join("\n")}\n-",
                    inline: true)
    embed.add_field(name: @home_team.abbrev,
                    value: "#{map_scores.map(&:last).join("\n")}\n-",
                    inline: true)

    live_map = get_live_map(maps)
    embed.image = { url: live_map.thumbnail } unless live_map.nil?
  end

  def add_home_color_to_embed(embed)
    embed.color = "0x#{@home_team.color}"
  end

  def add_maps_to_embed(embed, maps)
    return if @games.empty?

    embed.add_field(name: 'Maps', value: format_maps(maps))
  end

  def to_s
    return to_s_with_result unless @winner.nil?
    return 'TBD vs TBD' if @away_team.nil? && @home_team.nil?

    "#{@away_team} vs #{@home_team}"
  end

  def to_s_with_result
    away = "#{@away_team} #{@away_wins}"
    away = "**#{away}**" if @winner == @away_team

    home = "#{@home_team} #{@home_wins}"
    home = "**#{home}**" if @winner == @home_team

    "#{away} vs #{home}"
  end

  def score_str
    away = "#{@away_team.abbrev} #{@away_wins}"
    away = "**#{away}**" if @away_wins > @home_wins

    home = "#{@home_team.abbrev} #{@home_wins}"
    home = "**#{home}**" if @home_wins > @away_wins

    draw_str = @draws.zero? ? '' : " (#{@draws}D)"

    "#{away} - #{home}#{draw_str}"
  end

  protected

  attr_reader :start_date

  private

  def format_maps(maps)
    @games.map { |game| game.map(maps) }.join("\n")
  end

  def get_live_map(maps)
    @games.find(&:in_progress?)&.map(maps)
  end

  def format_map_scores
    scores = @games.map { |g| [g.away_score, g.home_score, g.concluded?] }

    scores.map do |away, home, is_concluded|
      next [away, home] unless is_concluded
      next %W[**#{away}** **#{home}**] if away == home
      next %W[**#{away}** *#{home}*] if away > home

      %W[*#{away}* **#{home}**]
    end
  end
end
