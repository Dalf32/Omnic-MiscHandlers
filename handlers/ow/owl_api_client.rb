# owl_api_client.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'ow_api_client'
require_relative 'api_rankings_response'
require_relative 'api_schedule_response'
require_relative 'api_standings_response'
require_relative 'api_players_response'
require_relative 'api_player_details_response'
require_relative 'api_v2_team_details_response'

class OwlApiClient < OwApiClient
  def get_team_details(team_id)
    response_hash = make_get_request(endpoint(:team_detail, team_id))
    ApiV2TeamDetailsResponse.new(response_hash)
  end

  def get_rankings
    response_hash = make_get_request(endpoint(:ranking))
    ApiRankingsResponse.new(response_hash)
  end

  def get_standings(season_year = nil)
    args = season_year.nil? ? {} : { season: season_year }
    response_hash = make_get_request(endpoint(:standings), args)
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
end
