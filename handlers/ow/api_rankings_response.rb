# api_rankings_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/ow_team'

class ApiRankingsResponse < HttpResponse
  def standings
    rankings = []

    body[:content].each do |team|
      rankings << [team[:placement], create_team(team[:competitor],
                                                 team[:records].first)]
    end

    rankings
  end

  private

  def create_team(comp, records)
    OwTeam.new(id: comp[:id], name: comp[:name]).tap do |team|
      team.basic_info(abbrev: comp[:abbreviatedName], home: comp[:homeLocation],
                      logo: comp[:logo], website: nil)
      team.colors(primary: comp[:primaryColor],
                  secondary: comp[:secondaryColor])

      team.records(wins: records[:matchWin], losses: records[:matchLoss],
                   map_wins: records[:gameWin], map_losses: records[:gameLoss],
                   map_draws: records[:gameTie])
    end
  end
end
