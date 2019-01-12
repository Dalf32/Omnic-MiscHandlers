# api_teams_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/ow_team'

class ApiTeamsResponse < HttpResponse
  def teams
    body[:competitors].map do |comp|
      OwTeam.new(id: comp.dig(:competitor, :id),
                 name: comp.dig(:competitor, :name))
    end
  end

  def full_teams
    teams.tap do |all_teams|
      body[:competitors].each do |competitor|
        comp = competitor[:competitor]
        team = all_teams.find { |t| t.eql?(comp[:id]) }

        team.basic_info(abbrev: comp[:abbreviatedName],
                        home: comp[:homeLocation], color: comp[:primaryColor],
                        logo: comp[:logo], website: nil)

        team.region = comp[:region]
        team.players(players(comp[:players]))
      end
    end
  end

  private

  def players(players_hash)
    return [] if players_hash.nil?

    players_hash.map do |player_hash|
      player_hash = player_hash[:player]

      OwPlayer.new(id: player_hash[:id], name: player_hash[:name]).tap do |player|
        player.basic_info(given_name: player_hash[:givenName],
                          family_name: player_hash[:familyName],
                          home: player_hash[:homeLocation],
                          country: player_hash[:nationality],
                          role: player_hash.dig(:attributes, :role),
                          number: player_hash.dig(:attributes, :player_number))
      end
    end
  end
end
