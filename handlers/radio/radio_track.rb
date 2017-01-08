# radio_track.rb
#
# Author::	Kyle Mullins

require 'json'
require 'chronic_duration'

require_relative '../../util/hash_util'

class RadioTrack
  attr_reader :artist, :album, :title, :uploader, :seconds_elapsed, :seconds_remaining, :seconds_total, :download_link, :id

  include HashUtil

  def initialize(artist:, album:, title:, uploader:, **other_info)
    @artist = artist
    @album = album
    @title = title
    @uploader = uploader

    #Optional for now, but soon we'll require this
    @id = other_info.dig(:id)

    #Optional info
    @seconds_elapsed = other_info.dig(:time_stats, :seconds_elapsed)
    @seconds_remaining = other_info.dig(:time_stats, :seconds_remaining)
    @seconds_total = other_info.dig(:time_stats, :seconds_total) or other_info.dig(:length)
    @played_time = other_info.dig(:played_time)
    @download_link = other_info.dig(:download_link)
  end

  def played_time
    unless @played_time.nil?
      Time.parse(@played_time)
    end
  end

  def pretty_print
    format_str = "  Artist: #{@artist}\n   Title: #{@title}"
    format_str +=  " (#{format_track_time(@seconds_elapsed)} / #{format_track_time(@seconds_total)})" unless @seconds_elapsed.nil? || @seconds_total.nil?
    format_str += "\n   Album: #{@album}\nUploader: #{@uploader}"
    format_str += "\n  Played: #{format_time_of_day(played_time)}" unless @played_time.nil?
    format_str
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