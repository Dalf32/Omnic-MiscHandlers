# owc_api_client.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'ow_api_client'
require_relative 'api_regions_response'
require_relative 'api_region_standings_response'

class OwcApiClient < OwApiClient
  def get_regions
    response_hash = make_get_request(endpoint(:regions))
    ApiRegionsResponse.new(response_hash)
  end

  def get_teams
    super(expand: 'team.content')
  end

  def get_standings
    response_hash = make_get_request(endpoint(:standings))
    ApiRegionStandingsResponse.new(response_hash)
  end
end
