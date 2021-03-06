# api_standings_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/ow_stage'

class ApiStandingsResponse < HttpResponse
  def standings(phase = :league, stage = 0)
    rankings = []

    body[:data].map do |team|
      records = case phase
                when :league
                  team[:league]
                when :preseason
                  team[:preseason]
                when :stage
                  team.dig(:stages, "stage#{stage}".to_sym)
                else
                  next
                end

      rankings << [records[:placement], create_team(team, records)]
    end

    rankings
  end

  private

  def create_team(team, records)
    OwTeam.new(id: team[:id], name: team[:name]).tap do |ow_team|
      ow_team.basic_info(abbrev: team[:abbreviatedName], home: '',
                         logo: team.dig(:logo, :main, :png), website: nil)

      colors = team[:colors]
      ow_team.colors(primary: colors.dig(:primary, :color),
                     secondary: colors.dig(:secondary, :color),
                     tertiary: colors.dig(:tertiary, :color))

      ow_team.records(wins: records[:matchWin], losses: records[:matchLoss],
                      map_wins: records[:gameWin],
                      map_losses: records[:gameLoss],
                      map_draws: records[:gameTie])
    end
  end
end
