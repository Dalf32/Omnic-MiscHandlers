# owc_handler.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'ow/ow_helper'
require_relative 'ow/owc_api_client'

class OwcHandler < CommandHandler
  include OwHelper

  feature :owc, default_enabled: true,
                description: 'Provides access to data from the Overwatch Contenders official API.'

  command(:owcregions, :list_regions)
    .feature(:owc).no_args.usage('owcregions')
    .description('Lists each of the OWC regions and their abbreviation.')

  command(:owcteam, :show_team)
    .feature(:owc).min_args(1).usage('owcteam <team>')
    .description('Shows details of the given OWC team.')

  command(:owcstandings, :show_standings)
    .feature(:owc).min_args(1).usage('owcstandings <region>')
    .description('Shows the standings for the current OWC season.')

  command(:owcschedule, :show_schedule)
    .feature(:owc).min_args(0).usage('owcschedule [region]')
    .description('Shows upcoming OWC matches.')

  command(:owclive, :show_live_state)
    .feature(:owc).no_args.usage('owclive')
    .description('Details the currently live match, or the next match if OWC is not yet live.')

  command(:owcscore, :show_score)
    .feature(:owc).no_args.usage('owcscore')
    .description('Shows the score of the currently live match in a spoiler-free manner.')

  def config_name
    :owc_api
  end

  def list_regions(event)
    handle_errors(event) do
      event.channel.start_typing
      regions_response = api_client.get_regions

      return 'An unexpected error occurred.' if regions_response.error?

      regions_str = "**Overwatch Contenders regions:**\n"
      regions_response.regions.each { |region| regions_str += "#{region}\n" }

      regions_str
    end
  end

  def show_team(event, *team_name)
    handle_errors(event) do
      event.channel.start_typing
      teams_response = api_client.get_teams

      return 'An unexpected error occurred.' if teams_response.error?

      teams = teams_response.full_teams
                            .find_all { |t| t.matches?(team_name.join(' ')) }

      return 'Team does not exist.' if teams.empty?
      return 'More than one team matches the query.' if teams.size > 1

      found_team = teams.first
      team_details = api_client.get_team_details(found_team.id)

      found_team.players(team_details.players) unless team_details.error?

      event.channel.send_embed(' ') do |embed|
        owc_basic_embed(embed)
        embed.url = "#{config.website_url}/teams"
        found_team.fill_min_embed(embed)
        embed.color = config.home_color if found_team.color.nil?
      end
    end
  end

  def show_standings(event, *region)
    handle_errors(event) do
      event.channel.start_typing
      standings_response = api_client.get_bracket

      return 'An unexpected error occurred.' if standings_response.error?

      regions_standings = standings_response.all_standings
      regions = regions_standings.keys
                                 .find_all { |r| r.matches?(region.join(' ')) }

      return 'Region does not exist.' if regions.empty?

      if regions.size > 1
        regions = regions.find_all { |r| r.exact_match?(region.join(' ')) }
        return 'More than one region matches the query.' unless regions.size == 1
      end

      chosen_region = regions.first
      standings = regions_standings[regions.first]

      if standings.is_a?(Hash)
        standings.each_pair do |group, ranks|
          send_standings(event, ranks,
                         "#{chosen_region.abbreviation} Group #{group} Season Standings")
        end

        nil # Otherwise we return the standings Hash
      else
        send_standings(event, standings,
                       "#{chosen_region.abbreviation} Season Standings")
      end
    end
  end

  def show_schedule(event, *region)
    handle_errors(event) do
      event.channel.start_typing
      schedule_response = api_client.get_schedule

      return 'An unexpected error occurred.' if schedule_response.error?

      current_stage = schedule_response.current_stage || schedule_response.upcoming_stage

      return 'No stage currently in progress.' if current_stage.nil?

      stages = [current_stage]
      playoffs = schedule_response.playoffs
      stages <<  playoffs unless current_stage.eql?(playoffs)

      regions_response = api_client.get_regions

      return 'An unexpected error occurred.' if regions_response.error?

      regions = regions_response.regions

      match_week_strategy = GroupByRegionStrategy.new(regions)

      unless region.empty?
        found_regions = regions.find_all { |r| r.matches?(region.join(' ')) }

        return 'Region does not exist.' if found_regions.empty?

        if found_regions.size > 1
          found_regions = found_regions.find_all { |r| r.exact_match?(region.join(' ')) }
          return 'More than one region matches the query.' unless found_regions.size == 1
        end

        match_week_strategy = FilterByRegionStrategy.new(found_regions.first)
      end

      stages.compact.each do |stage|
        match_week = stage.current_week || stage.upcoming_week
        next if match_week.match_count(match_strategy: match_week_strategy).zero?

        event.channel.send_embed(' ') do |embed|
          owc_basic_embed(embed, title = 'Overwatch Contenders Schedule')
          embed.title = "#{stage.name} #{match_week.name}"
          embed.url = "#{config.website_url}/schedule"
          match_week.fill_embed(embed, match_strategy: match_week_strategy)
        end
      end

      nil # Otherwise we return the stages Array
    end
  end

  def show_live_state(event)
    handle_errors(event) do
      event.channel.start_typing
      live_data = api_client.get_live_match

      return 'An unexpected error occurred.' if live_data.error?
      return 'There is no OWC match live at this time.' unless live_data.live_or_upcoming?

      maps_response = api_client.get_maps

      return 'An unexpected error occurred.' if maps_response.error?

      title = live_data.live_match_has_bracket? ? live_data.live_match_bracket_title : 'Overwatch Contenders'

      if live_data.live?
        live_match = live_data.live_match

        event.channel.send_embed(' ') do |embed|
          owc_basic_embed(embed, title)
          live_match_embed(embed, live_match, maps_response.maps)
          next_match_embed(embed, live_data.next_match,
                           live_data.time_to_next_match)
        end
      else
        next_match = live_data.live_match

        event.channel.send_embed(' ') do |embed|
          owc_basic_embed(embed, title)
          next_match_embed(embed, next_match, live_data.time_to_match)
          next_match.add_maps_to_embed(embed, maps_response.maps)
        end
      end
    end
  end

  def show_score(event)
    handle_errors(event) do
      event.channel.start_typing
      live_data = api_client.get_live_match

      return 'An unexpected error occurred.' if live_data.error?
      return 'There is no OWC match live at this time.' unless live_data.live?

      "||#{live_data.live_match.score_str}||"
    end
  end

  private

  def api_client
    @api_client ||= OwcApiClient.new(log: log, base_url: config.base_url,
                                     endpoints: config.endpoints,
                                     locale: config.locale)
  end

  def owc_basic_embed(embed, title = 'Overwatch Contenders')
    ow_basic_embed(embed, title)
    embed.color = config.home_color
  end

  def send_standings(event, standings, title)
    return 'An unexpected error occurred.' if standings.nil? || standings.empty?

    standings = standings.sort_by(&:first)
    leader = standings.first.last

    event.channel.send_embed(' ') do |embed|
      owc_basic_embed(embed)
      embed.title = title
      embed.url = "#{config.website_url}/standings"
      leader.fill_embed_logo(embed)
      embed.add_field(name: 'Team', value: format_team_ranks(standings),
                      inline: true)
      embed.add_field(name: 'Record (Map Diff)',
                      value: format_records(standings), inline: true)
    end
  end
end
