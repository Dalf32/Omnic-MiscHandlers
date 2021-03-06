# radio_track.rb
#
# Author::  Kyle Mullins

require 'json'
require 'chronic_duration'

require_relative '../../util/hash_util'

class RadioTrack
  attr_reader :artist, :album, :title, :uploader, :seconds_elapsed, :seconds_remaining, :seconds_total,
              :download_link, :album_art_path, :id, :on_behalf_of

  extend HashUtil

  def initialize(id:, artist:, album:, title:, uploader:, **other_info)
    @id = id
    @artist = artist
    @album = album
    @title = title
    @uploader = uploader

    # Optional info
    @seconds_elapsed = other_info[:seconds_elapsed]
    @seconds_remaining = other_info[:seconds_remaining]
    @seconds_total = other_info[:seconds_total] || other_info[:length]
    @played_time = other_info[:played_time]
    @download_link = other_info[:download_link]
    @album_art_path = other_info.dig(:art, :art_link)
    @on_behalf_of = other_info[:on_behalf_of]
    @bot_queued = other_info[:bot_queued]
  end

  def played_time
    Time.parse(@played_time) unless @played_time.nil?
  end

  def bot_queued?
    @bot_queued
  end

  def pretty_print
    format_str = "  Artist: #{@artist}\n   Title: #{@title}"
    format_str += ' ' + duration_str
    format_str += "\n   Album: #{@album}\nUploader: #{@uploader}"
    format_str += "\n  Played: #{format_time_of_day(played_time)}" unless @played_time.nil?
    format_str
  end

  def min_print
    "#{artist} - #{title}"
  end

  def fill_embed(embed)
    embed.add_field(name: 'Artist', value: @artist, inline: true)
    embed.add_field(name: 'Title', value: "#{@title} #{duration_str}", inline: true)
    embed.add_field(name: 'Album', value: @album, inline: true)
    embed.add_field(name: 'Queued by', value: @on_behalf_of, inline: true) unless bot_queued?
    embed.footer = { text: "Uploader: #{@uploader}" }
  end

  def duration_str
    return '' if @seconds_elapsed.nil? || @seconds_total.nil?

    "(#{format_track_time(@seconds_elapsed)} / #{format_track_time(@seconds_total)})"
  end

  def to_json
    JSON.generate(to_h)
  end

  def to_h
    { id: @id, artist: @artist, album: @album, title: @title, uploader: @uploader }
  end

  def self.from_json(json_str)
    json_hash = symbolize_keys(JSON.parse(json_str))
    RadioTrack.new(**json_hash)
  end

  private

  def format_track_time(time_secs)
    format = ChronicDuration.output(time_secs, format: :chrono)
    format = '0' + format if time_secs < 10
    format = '0:' + format unless format.include?(':')
    format
  end

  def format_time_of_day(time)
    time.getlocal.strftime('%Y-%m-%d %I:%M:%S %p %Z')
  end
end
