# owl_player.rb
#
# AUTHOR::  Kyle Mullins

class OwlPlayer
  attr_reader :id, :name, :role

  def initialize(id:, name:)
    @id = id
    @name = name
  end

  def basic_info(given_name:, family_name:, home:, country:, role:, number:)
    @real_name = "#{given_name} #{family_name}"
    @given_name = given_name
    @family_name = family_name
    @home = "#{home}, #{country}"
    @country = country
    @role = role
    @number = number
    self
  end

  def other_info(team:, headshot:, heroes:)
    @team = team
    @headshot = headshot
    @heroes = heroes
    self
  end

  def social(**links)
    @social_links = links
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

  def matches?(name)
    @name.downcase.include?(name.downcase)
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

  def stats_str
    @all_stats.map(&:format_table_row).join("\n")
  end

  def to_s
    str = @name
    str = "*##{@number}* " + str unless @number.nil?
    str += " :flag_#{@country.downcase}:" unless @country.nil?
    str += " *(#{@role})*" unless @role.nil?
    str
  end

  private

  def fill_socials_embed(embed)
    return if @social_links.nil? || @social_links.empty?

    slice_size = (@social_links.size / 2.0).ceil
    socials_split = format_socials.each_slice(slice_size).to_a

    embed.add_field(name: 'Social',
                    value: socials_split[0].join("\n"),
                    inline: true)
    embed.add_field(name: '-', value: socials_split[1].join("\n"),
                    inline: true)
  end

  def format_socials
    @social_links.map do |type, link|
      "[#{type.to_s.split('_').first.capitalize}](#{link})"
    end
  end

  def format_heroes
    return '-' if @heroes.nil? || @heroes.empty?
    @heroes.map(&:capitalize).join("\n")
  end

  def format_similar_players
    return '-' if @similar_players.nil? || @similar_players.empty?
    @similar_players.map(&:name).join("\n")
  end
end
