# api_live_match_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/ow_match'
require_relative 'model/ow_game'

class ApiLiveMatchResponse < HttpResponse
  def live_match
    create_match(body.dig(:data, :liveMatch))
  end

  def next_match
    return nil unless next_match?

    create_match(body.dig(:data, :nextMatch))
  end

  def live?
    body.dig(:data, :liveMatch, :liveStatus) == LIVE_STATE
  end

  def time_to_match
    body.dig(:data, :liveMatch, :timeToMatch)
  end

  def time_to_next_match
    body.dig(:data, :nextMatch, :timeToMatch)
  end

  def next_match?
    !body.dig(:data, :nextMatch, :id).nil?
  end

  def live_or_upcoming?
    !body.dig(:data, :liveMatch, :id).nil?
  end

  def live_match_has_bracket?
    !body.dig(:data, :liveMatch, :bracket).nil?
  end

  def live_match_bracket_title
    bracket_stage = body.dig(:data, :liveMatch, :bracket, :stage)
    "#{bracket_stage.dig(:tournament, :title)} #{bracket_stage[:title]}"
  end

  private

  LIVE_STATE = 'LIVE'.freeze

  def create_match(match)
    OwMatch.new(id: match[:id]).tap do |owl_match|
      owl_match.teams(away: create_team(match[:competitors][0]),
                      home: create_team(match[:competitors][1]))

      owl_match.games = match[:games].map { |game| create_game(game) }
      owl_match.result(away_wins: match.dig(:scores, 0, :value),
                       home_wins: match.dig(:scores, 1, :value),
                       draws: match.dig(:ties, 0), winner: nil)
    end
  end

  def create_team(team)
    return if team.nil?

    OwTeam.new(id: team[:id], name: team[:name]).tap do |owl_team|
      owl_team.basic_info(abbrev: team[:abbreviatedName],
                          home: team[:homeLocation], color: team[:primaryColor],
                          logo: team[:logo], website: nil)
    end
  end

  def create_game(game)
    OwGame.new(id: game[:id]).tap do |owl_game|
      owl_game.basic_info(map_id: game.dig(:attributes, :mapGuid),
                          state: game[:state])

      if owl_game.in_progress? || owl_game.concluded?
        owl_game.result(away_score: game[:points]&.[](0),
                        home_score: game[:points]&.[](1))
      end
    end
  end
end
