# api_schedule_response.rb
#
# AUTHOR::  Kyle Mullins

require 'date'

require_relative '../../api/http_response'
require_relative 'model/owl_stage'
require_relative 'model/owl_match'
require_relative 'model/owl_team'
require_relative 'model/owl_match_week'

class ApiScheduleResponse < HttpResponse
  def stages
    body.dig(:data, :stages).select { |s| s[:enabled] }.map do |stage|
      OwlStage.new(id: stage[:id], name: stage[:name]).tap do |owl_stage|
        owl_stage.weeks = stage[:weeks].map { |week| create_week(week) }
      end
    end
  end

  def start_date
    DateTime.strptime(body.dig(:data, :startDate), '%m-%d-%Y')
  end

  def end_date
    DateTime.strptime(body.dig(:data, :endDate), '%m-%d-%Y')
  end

  def current_stage
    stages.find(&:in_progress?)
  end

  def upcoming_stage
    stages.find(&:upcoming?)
  end

  private

  def create_week(week)
    OwlMatchWeek.new(id: week[:id], name: week[:name]).tap do |match_week|
      match_week.dates(start_date: to_date(week[:startDate]),
                       end_date: to_date(week[:endDate]))
      match_week.matches = week[:matches].map { |match| create_match(match) }
    end
  end

  def create_match(match)
    OwlMatch.new(id: match[:id]).tap do |owl_match|
      owl_match.basic_info(state: match[:state],
                           start_date: to_date(match[:startDateTS]),
                           end_date: to_date(match[:endDateTS]))

      owl_match.teams(away: create_team(match[:competitors][0]),
                      home: create_team(match[:competitors][1]))

      owl_match.result(away_wins: match.dig(:wins, 0),
                       home_wins: match.dig(:wins, 1),
                       draws: match.dig(:ties, 0),
                       winner: match.dig(:winner, :id))
    end
  end

  def create_team(team)
    OwlTeam.new(id: team[:id], name: team[:name]) unless team.nil?
  end

  def to_date(date)
    DateTime.strptime(date.to_s, '%Q') unless date.nil?
  end
end
