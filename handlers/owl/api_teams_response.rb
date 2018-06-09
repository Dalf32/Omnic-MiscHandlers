# api_teams_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/owl_team'

class ApiTeamsResponse < HttpResponse
  def teams
    body[:competitors].map do |comp|
      OwlTeam.new(id: comp.dig(:competitor, :id),
                  name: comp.dig(:competitor, :name))
    end
  end

  def full_teams
    teams.tap do |all_teams|
      body[:competitors].each do |competitor|
        comp = competitor[:competitor]
        team = all_teams.find { |t| t.eql?(comp[:id]) }

        team.basic_info(abbrev: comp[:abbreviatedName],
                        home: comp[:homeLocation],
                        country: comp[:addressCountry],
                        color: comp[:primaryColor], logo: comp[:logo])
      end
    end
  end
end
