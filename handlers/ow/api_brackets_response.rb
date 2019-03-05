# api_brackets_response.rb
#
# AUTHOR::  Kyle Mullins

class ApiBracketsResponse < HttpResponse
  def all_standings
    body.dig(:data, :regions).map do |region_standings|
      region = create_region(region_standings)
      groups = region_standings[:groups]
      next [region, nil] if groups.nil?

      if groups.count == 1
        ranks = groups.first[:ranks].map do |rank|
          [rank[:placement], create_team(rank[:competitor], rank[:records].first)]
        end
      else
        group_letter = 'A'
        ranks = {}

        groups.each do |group|
          ranks[group_letter] = create_ranks(group[:ranks])
          group_letter.succ!
        end
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

  def create_ranks(ranks)
    ranks.map do |rank|
      [rank[:placement], create_team(rank[:competitor], rank[:records].first)]
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
