# owc_handler.rb
#
# AUTHOR::  Kyle Mullins

require 'chronic_duration'

require_relative 'owc/owc_api_client'

class OwcHandler < CommandHandler
  feature :owc, default_enabled: true

  command(:owcregions, :list_regions)
    .feature(:owc).max_args(0).usage('owcregions')
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
    .feature(:owc).max_args(0).usage('owclive')
    .description('Details the currently live match, or the next match if OWC is not yet live.')

  command(:owcscore, :show_score)
    .feature(:owc).max_args(0).usage('owcscore')
    .description('Shows the score of the currently live match')

  def config_name
    :owc_api
  end

  def list_regions(event)
    event.channel.start_typing
    regions_response = api_client.get_regions

    return 'An unexpected error occurred.' if regions_response.error?

    regions_str = "**Overwatch Contenders regions:**\n"
    regions_response.regions.each { |region| regions_str += "#{region}\n" }

    regions_str
  end

  def show_team(event, *team)
    # TODO: Team details
  end

  def show_standings(event, *region)
    # TODO: Region standings
  end

  def show_schedule(event, *region)
    # TODO: Overall schedule
    # TODO: Region schedule
  end

  def show_live_state(event)
    event.channel.start_typing
    live_data = api_client.get_live_match

    return 'An unexpected error occurred.' if live_data.error?
    return 'There is no OWC match live at this time.' unless live_data.live_or_upcoming?

    maps_response = api_client.get_maps

    return 'An unexpected error occurred.' if maps_response.error?

    if live_data.live?
      live_match = live_data.live_match

      event.channel.send_embed(' ') do |embed|
        owc_basic_embed(embed)
        embed.title = 'Live Now!'
        embed.url = config.website_url
        embed.description = "***#{live_match}***"
        live_match.fill_live_embed(embed, maps_response.maps)
        add_next_match_embed(embed, live_data.next_match,
                             live_data.time_to_next_match)
      end
    else
      next_match = live_data.live_match

      event.channel.send_embed(' ') do |embed|
        owc_basic_embed(embed)
        add_next_match_embed(embed, next_match, live_data.time_to_match)
        next_match.add_maps_to_embed(embed, maps_response.maps)
      end
    end
  end

  def show_score(event)
    event.channel.start_typing
    live_data = api_client.get_live_match

    return 'An unexpected error occurred.' if live_data.error?
    return 'There is no OWL match live at this time.' unless live_data.live?

    live_data.live_match.score_str
  end

  private

  def api_client
    @api_client ||= OwcApiClient.new(log: log, base_url: config.base_url,
                                     endpoints: config.endpoints)
  end

  def format_time_left(time_ms)
    ChronicDuration.output(time_ms / 1000)
  end

  def footer_text
    "Retrieved from #{config.base_url}"
  end

  def owc_basic_embed(embed)
    embed.author = { name: 'Overwatch Contenders', url: config.website_url }
    embed.footer = { text: footer_text }
    embed.timestamp = Time.now
    embed.color = config.home_color
  end

  def add_next_match_embed(embed, match, time_to_match)
    return if match.nil?

    embed.add_field(name: 'Next Match', value: match, inline: true)
    embed.add_field(name: 'Time Until Start',
                    value: format_time_left(time_to_match), inline: true)
  end
end
