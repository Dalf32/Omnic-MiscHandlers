# api_v2_team_details_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/ow_team'
require_relative 'model/ow_player'

class ApiV2TeamDetailsResponse < HttpResponse
  def team
    data = body[:data]

    OwTeam.new(id: data[:id], name: data[:name]).tap do |team|
      team.basic_info(abbrev: data[:abbreviatedName], home: data[:location],
                      logo: data.dig(:logo, :main, :png),
                      website: data[:website])

      colors = data[:colors]
      team.colors(primary: colors.dig(:primary, :color),
                  secondary: colors.dig(:secondary, :color),
                  tertiary: colors.dig(:tertiary, :color))

      rank = data[:records]
      team.records(wins: rank[:matchWin], losses: rank[:matchLoss],
                   map_wins: rank[:gameWin], map_losses: rank[:gameLoss],
                   map_draws: rank[:gameTie])

      team.players(players)
      team.social(**extract_social_links(data[:accounts]))
    end
  end

  def players
    body.dig(:data, :players).map do |player_hash|
      OwPlayer.new(id: player_hash[:id], name: player_hash[:name]).tap do |player|
        player.given_name(full_name: player_hash[:fullName])
        player.basic_info(home: player_hash[:homeLocation], country: nil,
                          role: player_hash[:role],
                          number: player_hash[:number])
      end
    end
  end

  private

  def extract_social_links(accounts)
    accounts.map { |acc| [acc[:type].to_sym, acc[:url]] }.to_h
  end
end
