# ow_helper.rb
#
# AUTHOR::  Kyle Mullins

require 'chronic_duration'

module OwHelper
  protected

  def format_time_left(time_ms)
    ChronicDuration.output(time_ms / 1000)
  end

  def footer_text
    "Retrieved from #{config.base_url}"
  end

  def ow_basic_embed(embed, title)
    embed.author = { name: title, url: config.website_url }
    embed.footer = { text: footer_text }
    embed.timestamp = Time.now

    embed.footer[:icon_url] = config.icon_url if config.key?(:icon_url)
  end

  def next_match_embed(embed, match, time_to_match)
    return if match.nil?

    embed.add_field(name: 'Next Match', value: match, inline: true)
    embed.add_field(name: 'Time Until Start',
                    value: format_time_left(time_to_match), inline: true)
  end

  def live_match_embed(embed, live_match, maps)
    embed.title = 'Live Now!'
    embed.url = config.website_url
    embed.description = "***#{live_match}***"
    live_match.fill_live_embed(embed, maps)
  end

  def format_team_ranks(standings)
    str = standings.map { |rank, team| format('`%02d` %s', rank, team.name) }
                   .join("\n")
    "#{'-' * 33}\n" + str
  end

  def format_records(standings)
    str = standings.map { |_, team| "`#{team.record_str}`" }.join("\n")
    "#{'-' * 21}\n" + str
  end
end
