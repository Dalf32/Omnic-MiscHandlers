# api_player_details_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/ow_player'
require_relative 'model/ow_team'
require_relative 'model/owl_stat'

class ApiPlayerDetailsResponse < HttpResponse
  def player
    player_data = body.dig(:data, :player)

    create_player(player_data).tap do |player|
      player.other_info(team: create_team(body.dig(:data, :team, :data)),
                        headshot: player_data[:headshot],
                        heroes: player_data.dig(:attributes, :heroes))

      player.social(**extract_social_links(player_data[:accounts]))

      player.similar_players(*body.dig(:data, :similarPlayers)
                                  .map(&method(:create_player)))

      player.stats(all_stats: extract_stats(body.dig(:data, :stats, :all),
                                            body.dig(:data, :statRanks)),
                   hero_stats: {})
    end
  end

  private

  def create_team(team)
    OwTeam.new(id: team[:id], name: team[:name]).tap do |ow_team|
      ow_team.basic_info(abbrev: team[:abbreviatedName],
                         home: team[:homeLocation],
                         logo: team.dig(:logo, :main, :png), website: nil)

      colors = team[:colors]
      ow_team.colors(primary: colors.dig(:primary, :color),
                     secondary: colors.dig(:secondary, :color),
                     tertiary: colors.dig(:tertiary, :color))
    end
  end

  def create_player(player_data)
    OwPlayer.new(id: player_data[:id],
                 name: player_data[:name]).tap do |player|
      player.given_name(given_name: player_data[:givenName],
                        family_name: player_data[:familyName])
      player.basic_info(home: player_data[:homeLocation],
                        country: player_data[:nationality],
                        role: player_data.dig(:attributes, :role),
                        number: player_data.dig(:attributes, :player_number))
    end
  end

  def extract_social_links(accounts)
    links = {}

    accounts.select { |acc| acc[:isPublic] }
            .each { |acc| links[acc[:accountType].to_sym] = acc[:value] }

    links
  end

  def extract_stats(stat_data, stat_ranks)
    stat_map = {
      hero_damage_avg_per_10m: 'Hero Damage', healing_avg_per_10m: 'Healing',
      eliminations_avg_per_10m: 'Eliminations',
      final_blows_avg_per_10m: 'Final Blows', deaths_avg_per_10m: 'Deaths',
      ultimates_earned_avg_per_10m: 'Ultimates Earned',
      time_played_total: 'Total Time Played'
    }

    stat_data.map do |key, value|
      OwlStat.new(stat_map[key], value, rank: stat_ranks[key])
    end
  end
end
