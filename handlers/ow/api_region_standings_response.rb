# api_region_standings_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/ow_stage'

class ApiRegionStandingsResponse < HttpResponse
  def all_standings
    body.dig(:data, :regions).map do |region_standings|
      region = create_region(region_standings)
      ranks = region_standings[:ranks].map do |rank|
        [rank[:placement], create_team(rank[:competitor], rank[:records].first)]
      end

      [region, ranks]
    end.to_h
  end

  private

  def create_region(region)
    OwcRegion.new(id: region[:id], name: region[:name]).tap do |owc_region|
      owc_region.abbreviation = region[:abbreviation]
      owc_region.tournament_id = region[:tournamentId].to_i
    end
  end

  def create_team(team, records)
    OwTeam.new(id: team[:id], name: team[:name]).tap do |ow_team|
      ow_team.basic_info(abbrev: team[:abbreviatedName], home: '',
                         logo: team[:logo], website: nil)
      ow_team.colors(primary: team[:primaryColor],
                     secondary: team[:secondaryColor])

      ow_team.records(wins: records[:matchWin], losses: records[:matchLoss],
                      map_wins: records[:gameWin],
                      map_losses: records[:gameLoss],
                      map_draws: records[:gameTie])
    end
  end
end
