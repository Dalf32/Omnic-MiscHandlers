# api_player_details_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/owl_player'
require_relative 'model/owl_team'
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
                                 .map { |p| create_player(p) })

      player.stats(all_stats: extract_stats(body.dig(:data, :stats, :all),
                                            body.dig(:data, :statRanks)),
                   hero_stats: {})
    end
  end

  private

  def create_team(team)
    OwlTeam.new(id: team[:id], name: team[:name]).tap do |owl_team|
      owl_team.basic_info(abbrev: team[:abbreviatedName],
                          home: team[:homeLocation],
                          color: team.dig(:colors, :primary, :color),
                          logo: team.dig(:logo, :main, :png), website: nil)
    end
  end

  def create_player(player_data)
    OwlPlayer.new(id: player_data[:id],
                  name: player_data[:name]).tap do |player|
      player.basic_info(given_name: player_data[:givenName],
                        family_name: player_data[:familyName],
                        home: player_data[:homeLocation],
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
      damage_avg_per_10m: 'Damage', healing_avg_per_10m: 'Healing',
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
