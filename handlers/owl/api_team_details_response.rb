# api_team_details_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/owl_team'
require_relative 'model/owl_player'

class ApiTeamDetailsResponse < HttpResponse
  def team
    OwlTeam.new(id: body[:id], name: body[:name]).tap do |team|
      team.basic_info(abbrev: body[:abbreviatedName], home: body[:homeLocation],
                      country: body[:addressCountry],
                      color: body[:primaryColor], logo: body[:logo])

      rank = body[:ranking]
      team.records(wins: rank[:matchWin], losses: rank[:matchLoss],
                   map_wins: rank[:gameWin], map_losses: rank[:gameLoss],
                   map_draws: rank[:gameTie])

      team.players = players
      # TODO: team.schedule
    end
  end

  def players
    body[:players].map do |player_hash|
      OwlPlayer.new(id: player_hash[:id], name: player_hash[:name]).tap do |player|
        player.basic_info(given_name: player_hash[:givenName],
                          family_name: player_hash[:familyName],
                          home: player_hash[:homeLocation],
                          country: player_hash[:nationality],
                          role: player_hash.dig(:attributes, :role),
                          number: player_hash.dig(:attributes, :player_number))
      end
    end
  end

  def about_url
    body[:aboutUrl]
  end
end
