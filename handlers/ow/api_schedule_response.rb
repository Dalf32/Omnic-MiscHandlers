# api_schedule_response.rb
#
# AUTHOR::  Kyle Mullins

require 'date'

require_relative '../../api/http_response'
require_relative 'model/ow_stage'
require_relative 'model/ow_match'
require_relative 'model/ow_team'
require_relative 'model/ow_match_week'
require_relative 'model/owl_event'

class ApiScheduleResponse < HttpResponse
  def stages
    @stages ||= body.dig(:data, :stages).select { |s| s[:enabled] }.map do |stage|
      OwStage.new(id: stage[:id], name: stage[:name]).tap do |owl_stage|
        owl_stage.slug = stage[:slug]
        owl_stage.season = season
        owl_stage.weeks = stage[:weeks].map { |week| create_week(week) }
      end
    end
  end

  def season
    body.dig(:data, :id).to_i
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

  def playoffs
    stages.find(&:playoffs?)
  end

  private

  def create_week(week)
    OwMatchWeek.new(id: week[:id], name: week[:name]).tap do |match_week|
      match_week.season = season
      match_week.dates(start_date: to_date(week[:startDate]),
                       end_date: to_date(week[:endDate]))
      match_week.matches = week[:matches].map { |match| create_match(match) }
      match_week.events = week[:events].map { |event| create_event(event) } if week.key?(:events)
    end
  end

  def create_match(match)
    OwMatch.new(id: match[:id]).tap do |owl_match|
      owl_match.basic_info(state: match[:state],
                           start_date: to_date(match[:startDateTS]),
                           end_date: to_date(match[:endDateTS]))

      owl_match.teams(away: create_team(match[:competitors][0]),
                      home: create_team(match[:competitors][1]))

      owl_match.result(away_wins: match.dig(:wins, 0),
                       home_wins: match.dig(:wins, 1),
                       draws: match.dig(:ties, 0),
                       winner: match.dig(:winner, :id))

      owl_match.tournament = match.dig(:tournament, :id)
    end
  end

  def create_team(team)
    OwTeam.new(id: team[:id], name: team[:name]) unless team.nil?
  end

  def create_event(event)
    OwlEvent.new(type: event[:type], titles: event.dig(:data, :titles)).tap do |owl_event|
      owl_event.basic_info(loc_text: event.dig(:data, :locationText),
                           loc_url: event.dig(:data, :locationUrl),
                           descr_url: event.dig(:data, :descriptionUrl),
                           image: event.dig(:data, :imageUrl))
    end
  end

  def to_date(date)
    DateTime.strptime(date.to_s, '%Q') unless date.nil?
  end
end
