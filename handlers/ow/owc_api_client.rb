# owc_api_client.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/api_client'
require_relative 'api_regions_response'
require_relative 'api_live_match_response'
require_relative 'api_maps_response'

class OwcApiClient < ApiClient
  def initialize(log:, base_url:, endpoints:)
    super(log: log)

    @base_url = base_url
    @endpoints = endpoints
  end

  def get_regions
    response_hash = make_get_request(endpoint(:regions))
    ApiRegionsResponse.new(response_hash)
  end

  def get_live_match
    response_hash = make_get_request(endpoint(:live_match))
    ApiLiveMatchResponse.new(response_hash)
  end

  def get_maps
    response_hash = make_get_request(endpoint(:maps))
    ApiMapsResponse.new(response_hash)
  end

  private

  def endpoint(endpoint_name, *args)
    url_params = args.empty? ? '' : '/' + args.join('/')
    "#{@base_url}#{@endpoints[endpoint_name]}#{url_params}"
  end
end
