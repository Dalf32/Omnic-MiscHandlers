# ow_team.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'identifiable'
require_relative 'has_social_links'

class OwTeam
  include Identifiable
  include HasSocialLinks

  attr_reader :abbrev
  attr_accessor :region

  def basic_info(abbrev:, home:, logo:, website:)
    @abbrev = abbrev
    @home = home
    @logo = logo
    @website = website
    self
  end

  def colors(**args)
    @colors = args
  end

  def color
    @colors[:primary]
  end

  def records(wins:, losses:, map_wins:, map_losses:, map_draws:)
    @wins = wins
    @losses = losses
    @map_wins = map_wins
    @map_losses = map_losses
    @map_draws = map_draws
    self
  end

  def players(players)
    @players = players
    self
  end

  def upcoming_matches(matches)
    @matches = matches
  end

  def map_differential
    @map_wins - @map_losses
  end

  def fill_embed_logo(embed)
    embed.color = "0x#{color}"
    embed.thumbnail = { url: @logo }
  end

  def fill_embed(embed)
    embed.title = @name
    embed.url = @website
    fill_embed_logo(embed)
    embed.add_field(name: 'Record', value: "#{@wins} - #{@losses}", inline: true)
    embed.add_field(name: 'Maps *(Diff)*',
                    value: "#{@map_wins}-#{@map_losses}-#{@map_draws} *(#{map_differential_str})*",
                    inline: true)
    fill_socials_embed(embed)
    fill_players_embed(embed)
    fill_matches_embed(embed)
  end

  def fill_min_embed(embed)
    embed.title = @name
    embed.description = "Region: #{@region}" unless @region.nil?
    fill_embed_logo(embed)
    fill_players_embed(embed)
  end

  def map_differential_str
    format('%+d', map_differential)
  end

  def standings_str
    format('%-25s|%3s - %-3s|   %-3s',
           @name, @wins, @losses, map_differential_str)
  end

  def record_str
    format('%3s - %-3s (%s)', @wins, @losses, map_differential_str)
  end

  def to_s
    return "#{@name} (#{@abbrev})" unless @abbrev.nil?

    @name
  end

  private

  def fill_players_embed(embed)
    return if @players.nil? || @players.empty?

    slice_size = (@players.size / 2.0).ceil
    players_split = @players.sort_by(&:role).each_slice(slice_size).to_a

    embed.add_field(name: 'Players',
                    value: players_split[0].map(&:to_s).join("\n"),
                    inline: true)
    embed.add_field(name: '-', value: players_split[1].map(&:to_s).join("\n"),
                    inline: true)
  end

  def fill_matches_embed(embed)
    return if @matches.nil? || @matches.empty?

    date_mask = '%a, %d %b %Y'

    embed.add_field(name: 'Upcoming Matches',
                    value: @matches.map { |match| format_matchup(match) }.join("\n"),
                    inline: true)
    embed.add_field(name: '-',
                    value: @matches.map { |match| match.start_date.strftime(date_mask) }.join("\n"),
                    inline: true)
  end

  def format_matchup(match)
    return match.away_team.to_s if match.home_team.eql?(self)

    "*at* #{match.home_team}"
  end
end
