# api_v2_team_details_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/ow_team'
require_relative 'model/ow_player'
require_relative 'model/ow_match'

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
      team.upcoming_matches(upcoming_matches)
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

  def upcoming_matches
    body.dig(:data, :schedule).map do |match_hash|
      OwMatch.new(id: match_hash[:id]).tap do |ow_match|
        ow_match.basic_info(state: match_hash[:state],
                            start_date: to_date(match_hash[:startDate]),
                            end_date: to_date(match_hash[:endDate]))

        ow_match.teams(away: create_team(match_hash[:competitors][0]),
                       home: create_team(match_hash[:competitors][1]))
      end
    end
  end

  private

  def extract_social_links(accounts)
    accounts.map { |acc| [acc[:type].to_sym, acc[:url]] }.to_h
  end

  def create_team(team)
    OwTeam.new(id: team[:id], name: team[:name]) unless team.nil?
  end

  def to_date(date)
    DateTime.strptime(date.to_s, '%Q') unless date.nil?
  end
end
