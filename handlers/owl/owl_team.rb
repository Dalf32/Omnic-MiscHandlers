# owl_team.rb
#
# AUTHOR::  Kyle Mullins

class OwlTeam
  attr_reader :id, :name, :abbrev, :color
  attr_writer :players

  def initialize(id:, name:)
    @id = id
    @name = name
  end

  def basic_info(abbrev:, home:, country:, color:, logo:)
    @abbrev = abbrev
    @home = "#{home}, #{country}"
    @color = color
    @logo = logo
  end

  def records(wins:, losses:, map_wins:, map_losses:, map_draws:)
    @wins = wins
    @losses = losses
    @map_wins = map_wins
    @map_losses = map_losses
    @map_draws = map_draws
  end

  def players(players)
    @players = players
  end

  def map_differential
    @map_wins - @map_losses
  end

  def matches?(name)
    @name.downcase.include?(name.downcase)
  end

  def fill_embed_logo(embed)
    embed.color = "0x#{@color}"
    embed.thumbnail = { url: @logo }
  end

  def fill_embed(embed)
    embed.title = @name
    embed.add_field(name: 'Record', value: "#{@wins} - #{@losses}", inline: true)
    embed.add_field(name: 'Maps *(Diff)*',
                    value: "#{@map_wins}-#{@map_losses}-#{@map_draws} *(#{map_differential_str})*",
                    inline: true)
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

  def eql?(other)
    return false if other.nil?
    return @id == other if other.is_a? Numeric
    return @name == other if other.is_a? String
    @id == other.id
  end

  def to_s
    return "#{@name} (#{@abbrev})" unless @abbrev.nil?
    @name
  end

  private

  def fill_players_embed(embed)
    slice_size = (@players.size / 2.0).ceil
    players_split = @players.sort_by(&:role).each_slice(slice_size).to_a

    embed.add_field(name: 'Players',
                    value: players_split[0].map(&:to_s).join("\n"),
                    inline: true)
    embed.add_field(name: '-', value: players_split[1].map(&:to_s).join("\n"),
                    inline: true)
  end
end
