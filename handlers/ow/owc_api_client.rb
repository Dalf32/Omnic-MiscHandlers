# owc_api_client.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'ow_api_client'
require_relative 'api_regions_response'
require_relative 'api_live_match_response'
require_relative 'api_maps_response'

class OwcApiClient < OwApiClient
  def get_regions
    response_hash = make_get_request(endpoint(:regions))
    ApiRegionsResponse.new(response_hash)
  end
end
