# GdqRun
#
# AUTHOR::  Kyle Mullins

require 'chronic_duration'
require 'date'

class GdqRun
  attr_reader :time, :game, :runners, :length, :category, :platform, :host, :end_time

  def self.from_rows(row1, row2)
    category, platform = row2[1].split(' — ')
    runners = row1[2].split(', ')

    GdqRun.new(time: row1[0], game: row1[1], runners: runners, length: row2[0],
            category: category, platform: platform, host: row2[2])
  end

  def self.from_hash(run_hash)
    runners = run_hash['runners'].map { |runner_hash| runner_hash['name'] }
    host = run_hash.dig('hosts', 0, name)

    GdqRun.new(time: run_hash['starttime'], game: run_hash['name'], runners: runners,
               length: run_hash['run_time'], category: run_hash['category'],
               platform: run_hash['console'], host: host, end_time: run_hash['endtime'])
  end

  def initialize(time:, game:, runners:, length:, category:, platform:, host:, end_time: nil)
    @time = time.is_a?(String) ? DateTime.parse(time) : time
    @game = game
    @runners = runners
    @length = length.is_a?(String) ? ChronicDuration.parse(length) : length
    @category = category
    @platform = platform
    @host = host
    @end_time = end_time.is_a?(String) ? DateTime.parse(end_time) : end_time

    @end_time ||= @time + (@length / SECONDS_PER_DAY) unless @length.nil?
    @length ||= (@end_time - @time) * SECONDS_PER_DAY unless @end_time.nil?
  end

  def length_str
    format_time(@length)
  end

  def runners_str
    @runners.join(', ')
  end

  def time_to_end
    (@end_time - DateTime.now) * SECONDS_PER_DAY
  end

  def time_to_start
    (@time - DateTime.now) * SECONDS_PER_DAY
  end

  def time_since_start
    (DateTime.now - @time) * SECONDS_PER_DAY
  end

  def time_to_start_str
    format_time(time_to_start)
  end

  def time_since_start_str
    format_time(time_since_start)
  end

  def upcoming?
    (@time - DateTime.now).positive?
  end

  def in_progress?
    !upcoming? && !finished?
  end

  def finished?
    (@end_time - DateTime.now).negative?
  end

  def hosted?
    !@host.nil? && @host.length.positive?
  end

  def has_platform?
    !@platform.nil? && @platform.length.positive?
  end

  def matches_game?(game_name, full_match: false)
    @game.casecmp(game_name).zero? ||
      (!full_match && @game.downcase.start_with?(game_name.downcase))
  end

  def to_s(run_length_deco: 'in', start_time_deco: '')
    game_category = game_category_str(formatting: true, category_sep: ' - ')

    return "**#{runners_str}** ran #{game_category} #{run_length_deco} #{length_str}" if finished?

    host_str = hosted? ? ", hosted by #{@host}" : ''
    start_time_str = in_progress? ? 'Live now' : "Starting in #{time_to_start_str}"
    "**#{runners_str}** running #{game_category} #{run_length_deco} #{length_str}" +
        "\n  #{start_time_deco}#{start_time_str}#{host_str}"
  end

  def to_s_short(run_length_deco: 'in')
    game_category = game_category_str(formatting: false, category_sep: ' - ')
    "#{game_category} #{run_length_deco} #{length_str}"
  end

  def to_s_when
    game_category = game_category_str(formatting: false, category_sep: ' - ')
    start_time_str = if in_progress?
                       'is live now!'
                     elsif upcoming?
                       "starts in #{time_to_start_str}"
                     else
                       "was #{time_since_start_str} ago"
                     end
    "#{game_category} run by **#{runners_str}** #{start_time_str}"
  end

  def game_category_str(formatting:, category_sep: "\n")
    platform_str = has_platform? ? " (#{@platform})" : ''
    game_str = formatting ? "**#{@game}**" : @game

    game_str + platform_str + category_sep + @category
  end

  private

  SECONDS_PER_DAY = 24.0 * 60 * 60 unless defined?(SECONDS_PER_DAY)

  def format_time(time)
    ChronicDuration.output(time.to_i, format: :short, units: 2)
  end
end
