# ow_player.rb
#
# AUTHOR::  Kyle Mullins

require 'tabulo'
require_relative 'identifiable'
require_relative 'has_social_links'

class OwPlayer
  include Identifiable
  include HasSocialLinks

  def basic_info(home:, country:, role:, number:)
    @home = home
    @country = country
    @role = role
    @number = number

    @home = "#{@home}, #{@country}" unless @country.nil?
    self
  end

  def given_name(given_name: nil, family_name: nil, full_name: nil)
    @given_name = given_name
    @family_name = family_name

    if full_name.nil?
      @real_name = "#{given_name} #{family_name}"
    else
      @real_name = full_name
      @given_name, @family_name = *full_name.split(' ')
    end

    self
  end

  def other_info(team:, headshot:, heroes:)
    @team = team
    @headshot = headshot
    @heroes = heroes
    self
  end

  def similar_players(*players)
    @similar_players = players
    self
  end

  def stats(all_stats:, hero_stats:)
    @all_stats = all_stats
    @hero_stats = hero_stats
    self
  end

  def role
    @role || ''
  end

  def fill_embed(embed)
    embed.title = "##{@number} #{@given_name} \"#{@name}\" #{@family_name}"
    embed.description = "*#{@team.name} #{@role}\n#{@home}*"
    fill_socials_embed(embed)
    embed.add_field(name: 'Preferred Heroes', value: format_heroes,
                    inline: true)
    embed.add_field(name: 'Similar Players', value: format_similar_players,
                    inline: true)
    fill_embed_logo(embed)
  end

  def fill_embed_logo(embed)
    embed.color = "0x#{@team.color[1..-1]}"
    embed.thumbnail = { url: @headshot }
  end

  def stats_table(max_width)
    Tabulo::Table.new(@all_stats, border: :modern, column_padding: 0) do |table|
      table.add_column('As All Heroes', &:name)
      table.add_column('Avg/10 min', &:value_str)
      table.add_column('Rank', &:rank)
    end.pack(max_table_width: max_width).to_s
  end

  def to_s
    str = @name
    str = "*##{@number}* " + str unless @number.nil?
    str += " :flag_#{@country.downcase}:" unless @country.nil?
    str += " *(#{@role})*" unless @role.nil?
    str
  end

  private

  def format_heroes
    return '-' if @heroes.nil? || @heroes.empty?

    @heroes.map(&:capitalize).join("\n")
  end

  def format_similar_players
    return '-' if @similar_players.nil? || @similar_players.empty?

    @similar_players.map(&:name).join("\n")
  end
end
