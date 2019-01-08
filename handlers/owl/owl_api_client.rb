# owl_api_client.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/api_client'
require_relative 'api_teams_response'
require_relative 'api_team_details_response'
require_relative 'api_rankings_response'
require_relative 'api_schedule_response'
require_relative 'api_live_match_response'
require_relative 'api_maps_response'
require_relative 'api_standings_response'
require_relative 'api_players_response'
require_relative 'api_player_details_response'

class OwlApiClient < ApiClient
  def initialize(log:, base_url:, endpoints:)
    super(log: log)

    @base_url = base_url
    @endpoints = endpoints
  end

  def get_teams
    response_hash = make_get_request(endpoint(:teams))
    ApiTeamsResponse.new(response_hash)
  end

  def get_team_details(team_id)
    response_hash = make_get_request(endpoint(:team_detail, team_id),
                                     expand: 'team.content')
    ApiTeamDetailsResponse.new(response_hash)
  end

  def get_rankings
    response_hash = make_get_request(endpoint(:ranking))
    ApiRankingsResponse.new(response_hash)
  end

  def get_schedule
    response_hash = make_get_request(endpoint(:schedule))
    ApiScheduleResponse.new(response_hash)
  end

  def get_live_match
    response_hash = make_get_request(endpoint(:live_match))
    ApiLiveMatchResponse.new(response_hash)
  end

  def get_maps
    response_hash = make_get_request(endpoint(:maps))
    ApiMapsResponse.new(response_hash)
  end

  def get_standings
    response_hash = make_get_request(endpoint(:standings))
    ApiStandingsResponse.new(response_hash)
  end

  def get_players
    response_hash = make_get_request(endpoint(:players))
    ApiPlayersResponse.new(response_hash)
  end

  def get_player_details(player_id)
    response_hash = make_get_request(endpoint(:players, player_id),
                                     expand: 'stats,stat.ranks,similarPlayers,team')
    ApiPlayerDetailsResponse.new(response_hash)
  end

  def current_stage
    schedule_response = get_schedule

    return nil if schedule_response.error?

    schedule_response.current_stage || schedule_response.upcoming_stage
  end

  def current_season
    schedule_response = get_schedule

    return 1 if schedule_response.error?

    schedule_response.season - 2017
  end

  private

  def endpoint(endpoint_name, *args)
    url_params = args.empty? ? '' : '/' + args.join('/')
    "#{@base_url}#{@endpoints[endpoint_name]}#{url_params}"
  end
end
