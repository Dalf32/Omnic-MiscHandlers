# api_rankings_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'

class ApiRankingsResponse < HttpResponse
  def standings
    rankings = {}

    body[:content].each do |team|
      rankings[team[:placement]] = create_team(team[:competitor],
                                               team[:records].first)
    end

    rankings
  end

  private

  def create_team(comp, records)
    OwlTeam.new(id: comp[:id], name: comp[:name]).tap do |team|
      team.basic_info(abbrev: comp[:abbreviatedName], home: comp[:homeLocation],
                      country: comp[:addressCountry],
                      color: comp[:primaryColor], logo: comp[:logo])

      team.records(wins: records[:matchWin], losses: records[:matchLoss],
                   map_wins: records[:gameWin], map_losses: records[:gameLoss],
                   map_draws: records[:gameTie])
    end
  end
end
