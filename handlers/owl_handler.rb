# owl_handler.rb
#
# AUTHOR::  Kyle Mullins

require 'chronic_duration'

require_relative 'owl/owl_api_client'

class OwlHandler < CommandHandler
  feature :owl, default_enabled: true

  command(:owlteam, :show_team)
    .feature(:owl).min_args(1).usage('owlteam <team>')
    .description('Shows details of the given OWL team.')
  command(:owlstandings, :show_standings)
    .feature(:owl).max_args(0).usage('owlstandings')
    .description('Shows the standings for the current OWL season.')
  command(:owlschedule, :show_schedule)
    .feature(:owl).max_args(0).usage('owlschedule')
    .description('Shows upcoming OWL matches.')
  command(:owllive, :show_live_state)
    .feature(:owl).max_args(0).usage('owllive')
    .description('Details the currently live match, or the next match if OWL is not yet live.')
  command(:owlstage, :show_stage_rank)
    .feature(:owl).args_range(0, 1).usage('owlstage [stage_num]')
    .description('Shows the standings for the current OWL stage.')
  command(:owlscore, :show_score)
    .feature(:owl).max_args(0).usage('owlscore')
    .description('Shows the score of the currently live match')

  def config_name
    :owl_api
  end

  def show_team(event, *team_name)
    teams_response = api_client.get_teams

    return 'An unexpected error occurred.' if teams_response.error?

    teams = teams_response.teams
                          .find_all { |t| t.matches?(team_name.join(' ')) }

    return 'Team does not exist.' if teams.empty?
    return 'More than one team matches the query.' if teams.size > 1

    team_details = api_client.get_team_details(teams.first.id)

    return 'An unexpected error occurred.' if team_details.error?

    event.channel.send_embed(' ') do |embed|
      owl_basic_embed(embed)
      embed.url = team_details.about_url
      team_details.team.fill_embed(embed)
    end
  end

  def show_standings(event)
    standings_response = api_client.get_standings

    return 'An unexpected error occurred.' if standings_response.error?

    standings = standings_response.standings

    send_standings(event, standings, 'Season Standings',
                   'https://overwatchleague.com/standings/season/1/league')
  end

  def show_schedule(event)
    schedule_response = api_client.get_schedule

    return 'An unexpected error occurred.' if schedule_response.error?

    current_stage = schedule_response.current_stage

    return 'No stage currently in progress.' if current_stage.nil?

    current_week = current_stage.current_week

    event.channel.send_embed(' ') do |embed|
      owl_basic_embed(embed)
      embed.author = { name: 'Overwatch League Schedule' }
      embed.title = "#{current_stage.name} #{current_week.name}"
      embed.url = 'https://overwatchleague.com/schedule'
      current_week.fill_embed(embed)
    end
  end

  def show_live_state(event)
    live_data = api_client.get_live_match

    return 'An unexpected error occurred.' if live_data.error?
    return 'There is no OWL match live at this time.' unless live_data.live_or_upcoming?

    maps_response = api_client.get_maps

    return 'An unexpected error occurred.' if maps_response.error?

    if live_data.live?
      live_match = live_data.live_match

      event.channel.send_embed(' ') do |embed|
        owl_basic_embed(embed)
        embed.title = 'Live Now!'
        embed.url = 'https://overwatchleague.com'
        embed.description = "***#{live_match}***"
        live_match.fill_live_embed(embed, maps_response.maps)
        live_match.add_home_color_to_embed(embed)
        add_next_match_embed(embed, live_data.next_match,
                             live_data.time_to_next_match)
      end
    else
      next_match = live_data.live_match

      event.channel.send_embed(' ') do |embed|
        owl_basic_embed(embed)
        add_next_match_embed(embed, next_match, live_data.time_to_match)
        next_match.add_maps_to_embed(embed, maps_response.maps)
        next_match.add_home_color_to_embed(embed)
      end
    end
  end

  def show_stage_rank(event, *stage_num)
    if stage_num.empty?
      current_stage = api_client.current_stage

      return 'No stage currently in progress.' if current_stage.nil?

      stage_standings(event, current_stage.id, current_stage.name)
    else
      stage_num = stage_num.first
      return 'Invalid Stage number.' unless %w[1 2 3 4].include?(stage_num)

      stage_standings(event, stage_num.to_i, "Stage #{stage_num}")
    end
  end

  def show_score(_event)
    live_data = api_client.get_live_match

    return 'An unexpected error occurred.' if live_data.error?
    return 'There is no OWL match live at this time.' unless live_data.live?

    live_data.live_match.score_str
  end

  private

  def api_client
    @api_client ||= OwlApiClient.new(log: log, base_url: config.base_url,
                                     endpoints: config.endpoints)
  end

  def standings_header
    format("%14s%-14s|%4s%-5s|%6s\n%s", 'Te', 'am', 'Rec', 'ord',
           'Diff', '-' * 46)
  end

  def format_standings(standings)
    standings.map { |rank, team| format('%02d %s', rank, team.standings_str) }
             .join("\n")
  end

  def send_standings(event, standings, title, url)
    return 'An unexpected error occurred.' if standings.nil? || standings.empty?

    standings = standings.sort_by(&:first)
    leader = standings.first.last

    event.channel.send_embed(' ') do |embed|
      owl_basic_embed(embed)
      embed.title = title
      embed.url = url
      embed.description = "```#{standings_header}\n#{format_standings(standings)}```"
      leader.fill_embed_logo(embed)
    end
  end

  def stage_standings(event, stage_id, stage_name)
    standings_response = api_client.get_standings

    return 'An unexpected error occurred.' if standings_response.error?

    standings = standings_response.standings(:stage, stage_id)

    send_standings(event, standings, "#{stage_name} Standings",
                   'https://overwatchleague.com/standings')
  end

  def format_time_left(time_ms)
    ChronicDuration.output(time_ms / 1000)
  end

  def footer_text
    "Retrieved from #{config.base_url}"
  end

  def owl_basic_embed(embed)
    embed.author = { name: 'Overwatch League' }
    embed.footer = { text: footer_text }
    embed.timestamp = Time.now
  end

  def add_next_match_embed(embed, match, time_to_match)
    return if match.nil?
    embed.add_field(name: 'Next Match', value: match, inline: true)
    embed.add_field(name: 'Time Until Start',
                    value: format_time_left(time_to_match), inline: true)
  end
end
