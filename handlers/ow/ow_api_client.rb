# ow_api_client.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/api_client'

class OwApiClient < ApiClient
  def initialize(log:, base_url:, endpoints:)
    super(log: log)

    @base_url = base_url
    @endpoints = endpoints
  end

  def get_live_match
    response_hash = make_get_request(endpoint(:live_match))
    ApiLiveMatchResponse.new(response_hash)
  end

  def get_maps
    response_hash = make_get_request(endpoint(:maps))
    ApiMapsResponse.new(response_hash)
  end

  protected

  def endpoint(endpoint_name, *args)
    url_params = args.empty? ? '' : '/' + args.join('/')
    "#{@base_url}#{@endpoints[endpoint_name]}#{url_params}"
  end
end
