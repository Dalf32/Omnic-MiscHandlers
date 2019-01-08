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
    .feature(:owl).args_range(0, 2).usage('owlstage [season_year stage_num]')
    .description('Shows the standings for the current OWL stage.')

  command(:owlscore, :show_score)
    .feature(:owl).max_args(0).usage('owlscore')
    .description('Shows the score of the currently live match')

  command(:owlplayer, :show_player)
    .feature(:owl).args_range(1, 2).usage('owlplayer <player> [hero]')
    .description('Shows details of the given OWL player and optionally, detailed stats for the given hero.')

  def config_name
    :owl_api
  end

  def show_team(event, *team_name)
    event.channel.start_typing
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
      team_details.team.fill_embed(embed)
    end
  end

  def show_standings(event)
    event.channel.start_typing
    standings_response = api_client.get_standings

    return 'An unexpected error occurred.' if standings_response.error?

    standings = standings_response.standings
    season_num = api_client.current_season

    send_standings(event, standings, 'Season Standings',
                   "#{config.website_url}/standings/season/#{season_num}/league")
  end

  def show_schedule(event)
    # TODO: Support passing year
    event.channel.start_typing
    schedule_response = api_client.get_schedule

    return 'An unexpected error occurred.' if schedule_response.error?

    current_stage = schedule_response.current_stage || schedule_response.upcoming_stage

    return 'No stage currently in progress.' if current_stage.nil?

    current_week = current_stage.current_week || current_stage.upcoming_week

    event.channel.send_embed(' ') do |embed|
      owl_basic_embed(embed)
      embed.author = { name: 'Overwatch League Schedule',
                       url: config.website_url }
      embed.title = "#{current_stage.name} #{current_week.name}"
      embed.url = "#{config.website_url}/schedule"
      current_week.fill_embed(embed)
    end
  end

  def show_live_state(event)
    event.channel.start_typing
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
        embed.url = config.website_url
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

  def show_stage_rank(event, *args)
    if args.empty?
      event.channel.start_typing
      current_stage = api_client.current_stage

      return 'No stage currently in progress.' if current_stage.nil?

      stage_standings(event, current_stage.season, current_stage.number)
    elsif args.count == 1
      'Both the Season year and desired Stage number must be provided.'
    else
      season_year, stage_num = *args
      season_year = season_year.to_i
      return 'Invalid Season year.' unless season_year >= 2018
      return 'Invalid Stage number.' unless %w[1 2 3 4].include?(stage_num)

      event.channel.start_typing
      stage_standings(event, season_year, stage_num)
    end
  end

  def show_score(event)
    event.channel.start_typing
    live_data = api_client.get_live_match

    return 'An unexpected error occurred.' if live_data.error?
    return 'There is no OWL match live at this time.' unless live_data.live?

    live_data.live_match.score_str
  end

  def show_player(event, player_name, *hero_name)
    event.channel.start_typing
    players_response = api_client.get_players

    return 'An unexpected error occurred.' if players_response.error?

    players = players_response.players
                              .find_all { |p| p.matches?(player_name) }

    return 'Player does not exist.' if players.empty?

    if players.size > 1
      players = players.find_all { |p| p.exact_match?(player_name) }
      return 'More than one player matches the query.' unless players.size == 1
    end

    player_details = api_client.get_player_details(players.first.id)

    return 'An unexpected error occurred.' if player_details.error?

    player = player_details.player

    # Find hero if given
    return 'Per-hero stats are not yet implemented.' unless hero_name.empty?

    event.channel.send_embed(' ') do |embed|
      owl_basic_embed(embed)
      player.fill_embed(embed)
      embed.url = "#{config.website_url}/players/#{player.id}"
      embed.add_field(name: 'Basic Stats',
                      value: "```#{stats_header}\n#{player.stats_str}```")
    end
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

  def stage_standings(event, season_year, stage_num)
    standings_response = api_client.get_standings(season_year)

    return 'An unexpected error occurred.' if standings_response.error?

    standings = standings_response.standings(:stage, stage_num)

    season_num = season_year - 2017
    send_standings(event, standings, "Stage #{stage_num} Standings",
                   "#{config.website_url}/standings/season/#{season_num}/stage/#{stage_num}")
  end

  def stats_header
    format("%10s%-9s|%7s%-7s|%6s\n%s", 'As All', ' Heroes', 'Avg/1', '0 min',
           'Rank', '-' * 43)
  end

  def format_time_left(time_ms)
    ChronicDuration.output(time_ms / 1000)
  end

  def footer_text
    "Retrieved from #{config.base_url}"
  end

  def owl_basic_embed(embed)
    embed.author = { name: 'Overwatch League', url: config.website_url }
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
