# radio_api_handler.rb
#
# Author::	Kyle Mullins

require_relative 'radio/radio_api_client'
require_relative 'radio/radio_track'

class RadioApiHandler < CommandHandler
  command :radio, :radio_link, description: 'Posts a link to the WLTM radio website.'
  command :playing, :show_now_playing, min_args: 0, max_args: 1, description: 'Displays information about the currently playing track on WLTM radio.', limit: { delay: 10, action: :on_limit }
  command :listeners, :show_current_listeners, description: 'Shows the number of people listening to WLTM radio.', limit: { delay: 10, action: :on_limit }
  command :history, :show_recent_history, description: 'Shows the tracks that have played in the last hour', limit: { delay: 10, action: :on_limit }
  command :restart, :restart_now_playing_thread, required_permissions: [:administrator],
      description: 'Restarts the thread that updates the Now Playing thread.', limit: { delay: 60, action: :on_limit }
  command :skip, :skip_track, description: 'Votes to skip the track currently playing on WLTM radio.', limit: { delay: 5, action: :on_limit}

  event :ready, :start_now_playing_thread

  def config_name
    :radio_api
  end

  def redis_name
    :radio_api
  end

  def radio_link(_event)
    config.base_url
  end

  def show_now_playing(_event, *args)
    return rewind_now_playing(_event, *args) unless args.empty?

    track = api_client.get_now_playing
    "***Now Playing***\n```#{track.pretty_print}```"
  end

  def rewind_now_playing(_event, rewind_str)
    rewind_steps = rewind_str.match(/[~-]+/)
    return if rewind_steps.nil?

    rewind_steps = rewind_steps[0].length
    rewind_steps = [rewind_steps, MAX_REWIND_STEPS].min

    history_list = api_client.get_history(start: last_hour, desc: true, page: 0, pagesize: rewind_steps + 1)

    unless history_list.nil?
      "**The last #{rewind_steps} tracks played**\n```#{format_track_info_for_history(history_list[1..-1])}```"
    end
  end

  def show_current_listeners(_event)
    current_listeners = api_client.get_current_listeners
    "#{current_listeners} current listener#{current_listeners == 1 ? '' : 's'}#{current_listeners.zero? ? ' :slight_frown:' : ''}"
  end

  def show_recent_history(event)
    history_list = api_client.get_history(start: last_hour)

    unless history_list.nil?
      formatted_output = format_track_info_for_history(history_list)
      formatted_output.scan(/.{1,1900}/m).each_with_index do |split_msg, n|
        event.message.reply("#{n == 0 ? "**Tracks played in the last hour**\n" : ''}```#{split_msg}```")
      end

      nil
    end
  end

  def skip_track(event)
    response_hash = api_client.skip_track(event.author.distinct)

    if is_error_response?(response_hash)
      return 'You cannot vote to skip the current track more than once.' if /user cannot vote to skip/ === response_hash.dig(:response_body, :error)

      'An error occurred, please contact an admin.'
    elsif is_track_skipped?(response_hash)
      Thread.new do
        sleep(5)
        track = api_client.get_now_playing
        bot.game = track.artist || '-' unless track.nil?
      end

      'The current track will be skipped shortly.'
    elsif response_hash[:current_listeners] == '0'
      'You cannot skip tracks when no one is listening!'
    else
      "Not enough skip votes yet. #{response_hash[:current_skips]} Skips / #{response_hash[:current_listeners]} Listeners"
    end
  end

  def like_track(_event)
    track = api_client.get_now_playing

    tracks_store.hsetnx(track.id, track.to_json)
    likes_store.sadd(track.id)

    'Track added to your likes!'
  end

  def get_likes(_event)
    tracks_store.hmget(*likes_store.smembers).map do |track_json|
      RadioTrack.from_json(track_json).pretty_print
    end.join("\n\n--------------------\n\n")
  end

  def start_now_playing_thread(_event)
    global_redis.set(:sleep_duration, MIN_SLEEP_DURATION)
    thread(:update_now_playing_0, &method(:update_now_playing))
    @@last_used_thread = :update_now_playing_0
  end

  def restart_now_playing_thread(event)
    old_thread = thread(@@last_used_thread)

    event.message.reply('Killing the old now playing thread...')

    old_thread.kill
    old_thread.join

    @@last_used_thread = @@last_used_thread.succ

    event.message.reply('Starting new now playing thread...')

    thread(@@last_used_thread, &method(:update_now_playing))

    'New thread started!'
  end

  def on_limit(event, time_remaining)
    time_remaining = time_remaining.ceil
    message = "Slow down there, buddy. Wait #{time_remaining} more second#{time_remaining == 1 ? '' : 's'} before you try again."
    bot.send_temporary_message(event.message.channel.id, message, time_remaining + 2)

    nil
  end

  private

  def api_client
    @api_client ||= RadioApiClient.new(**config, log: log)
  end

  def update_now_playing
    while true
      if bot.connected?
        track = api_client.get_now_playing

        unless track.nil?
          bot.game = track.artist || '-'
          sleep_until_next_track(track.seconds_remaining)
        end
      else
        log.warn('Now Playing status not updated because Bot not connected to Discord.')
        sleep_until_next_track(nil)
      end

      log.debug('Waking up.')
    end
  rescue StandardError => e
    log.error(e)
  end

  def is_track_skipped?(skip_response)
    skip_response[:current_skip_percentage] >= skip_response[:skip_percentage_threshold]
  end

  def is_error_response?(request_response)
    !request_response[:http_code].nil? && !request_response[:http_code].start_with?('2')
  end

  def likes_store
    Redis::Namespace.new('likes', redis: user_redis)
  end

  def tracks_store
    Redis::Namespace.new('tracks', redis: global_redis)
  end

  MIN_SLEEP_DURATION = 10 unless defined? MIN_SLEEP_DURATION
  MAX_SLEEP_DURATION = 320 unless defined? MAX_SLEEP_DURATION
  MAX_REWIND_STEPS = 5 unless defined? MAX_REWIND_STEPS

  def sleep_until_next_track(time_remaining)
    sleep_duration = if time_remaining.nil? || time_remaining <= 0
      retry_duration = global_redis.get(:sleep_duration).to_i
      global_redis.set(:sleep_duration, retry_duration * 2) unless retry_duration == MAX_SLEEP_DURATION

      log.info("No track info, retrying in #{retry_duration}s")
      retry_duration
    else
      global_redis.set(:sleep_duration, MIN_SLEEP_DURATION)
      time_remaining + 2
    end

    log.debug("Sleeping for #{sleep_duration}s")
    sleep(sleep_duration)
  end

  def format_track_info_for_history(hist_list)
    hist_list.map(&:pretty_print).join("\n\n--------------------\n\n")
  end

  def last_hour
    (Time.now - (60 * 60)).to_i
  end
end