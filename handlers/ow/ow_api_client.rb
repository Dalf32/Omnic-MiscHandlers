# ow_api_client.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/api_client'
require_relative 'api_live_match_response'
require_relative 'api_maps_response'
require_relative 'api_teams_response'

class OwApiClient < ApiClient
  def initialize(log:, base_url:, endpoints:, locale:)
    super(log: log)

    @base_url = base_url
    @endpoints = endpoints
    @locale = locale
  end

  def get_live_match
    response_hash = make_get_request(endpoint(:live_match))
    ApiLiveMatchResponse.new(response_hash)
  end

  def get_maps
    response_hash = make_get_request(endpoint(:maps))
    ApiMapsResponse.new(response_hash)
  end

  def get_teams(**query_args)
    response_hash = make_get_request(endpoint(:teams), query_args)
    ApiTeamsResponse.new(response_hash)
  end

  def get_schedule(**query_args)
    response_hash = make_get_request(endpoint(:schedule), query_args)
    ApiScheduleResponse.new(response_hash)
  end

  protected

  def endpoint(endpoint_name, *args)
    url_params = args.empty? ? '' : '/' + args.join('/')
    "#{@base_url}#{@endpoints[endpoint_name]}#{url_params}"
  end

  def make_get_request(api_url, use_ssl: true, **query_args)
    super(api_url, use_ssl: use_ssl, **{ locale: @locale }.merge(query_args))
  end
end
