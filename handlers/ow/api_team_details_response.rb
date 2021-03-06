# api_team_details_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/ow_team'
require_relative 'model/ow_player'

class ApiTeamDetailsResponse < HttpResponse
  def team
    OwTeam.new(id: body[:id], name: body[:name]).tap do |team|
      team.basic_info(abbrev: body[:abbreviatedName], home: body[:homeLocation],
                      logo: body[:logo],
                      website: body.dig(:content, :teamWebsite))
      team.colors(primary: body[:primaryColor],
                  secondary: body[:secondaryColor])

      rank = body[:ranking]
      team.records(wins: rank[:matchWin], losses: rank[:matchLoss],
                   map_wins: rank[:gameWin], map_losses: rank[:gameLoss],
                   map_draws: rank[:gameTie])

      team.players(players)
      team.social(**extract_social_links(body[:accounts]))
    end
  end

  def players
    body[:players].map do |player_hash|
      OwPlayer.new(id: player_hash[:id], name: player_hash[:name]).tap do |player|
        player.given_name(given_name: player_hash[:givenName],
                          family_name: player_hash[:familyName])
        player.basic_info(home: player_hash[:homeLocation],
                          country: player_hash[:nationality],
                          role: player_hash.dig(:attributes, :role),
                          number: player_hash.dig(:attributes, :player_number))
      end
    end
  end

  private

  def extract_social_links(accounts)
    links = {}

    accounts.select { |acc| acc[:isPublic] }
            .each { |acc| links[acc[:accountType].to_sym] = acc[:value] }

    links
  end
end
