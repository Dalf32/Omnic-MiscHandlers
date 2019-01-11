# api_regions_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/owc_region'

class ApiRegionsResponse < HttpResponse
  def regions
    body[:data].map do |region|
      OwcRegion.new(id: region[:id], name: region[:name]).tap do |owc_region|
        owc_region.abbreviation = region[:abbreviation]
        owc_region.tournament_id = region[:tournamentId].to_i
      end
    end
  end
end
