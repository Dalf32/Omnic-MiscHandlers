# radio_api_handler.rb
#
# Author::	Kyle Mullins

require 'chronic_duration'

require_relative 'radio/radio_api_client'
require_relative 'radio/radio_track'
require_relative 'radio/api_skip_response'
require_relative 'radio/api_enqueue_response'

class RadioApiHandler < CommandHandler
  feature :radio, default_enabled: true

  command :radio, :radio_link, feature: :radio, description: 'Posts a link to the WLTM radio website.'
  command :playing, :show_now_playing, min_args: 0, max_args: 1, feature: :radio,
      description: 'Displays information about the currently playing track on WLTM radio.', limit: { delay: 10, action: :on_limit }
  command :listeners, :show_current_listeners, feature: :radio, limit: { delay: 10, action: :on_limit },
      description: 'Shows the number of people listening to WLTM radio.'
  command :history, :show_recent_history, feature: :radio, limit: { delay: 10, action: :on_limit },
      description: 'Shows the tracks that have played in the last hour'
  command :restart, :restart_now_playing_thread, required_permissions: [:administrator], feature: :radio,
      description: 'Restarts the thread that updates the Now Playing thread.', limit: { delay: 60, action: :on_limit }
  command :skip, :skip_track, feature: :radio, limit: { delay: 5, action: :on_limit},
      description: 'Votes to skip the track currently playing on WLTM radio.'
  command :queuetrack, :enqueue_track, min_args: 1, feature: :radio, limit: { delay: 10, action: :on_limit },
      description: 'Enqueues a single track to be played on WLTM radio or returns a list of all the files matching your criteria.'
  command :queuealbum, :enqueue_album, min_args: 1, feature: :radio, limit: { delay: 10, action: :on_limit },
          description: 'Enqueues an entire album to be played on WLTM radio or returns a list of all the folders matching your criteria.'
  command :like, :like_track, min_args: 0, max_args: 1, feature: :radio, description: 'Adds the track currently playing on WLTM radio to your likes.'
  command :likes, :show_likes, max_args: 0, feature: :radio, description: "Lists the tracks you've liked from WLTM radio."
  command :clrlikes, :clear_likes, max_args: 0, feature: :radio, description: 'Clears all of your liked Tracks.'

  event :ready, :start_now_playing_thread

  def config_name
    :radio_api
  end

  def redis_name
    :radio_api
  end

  def radio_link(event)
    event.channel.send_embed(' ') do |embed|
      embed.title = config.radio_name
      embed.description = config.base_url
      embed.url = config.base_url
      embed.image = { url: config.splash_image }
      embed.color = random_color
    end
  end

  def show_now_playing(event, *args)
    return rewind_now_playing(event, *args) unless args.empty?

    track = api_client.get_now_playing

    event.channel.send_embed(' ') do |embed|
      fill_track_embed(embed)
      embed.description = "***[Now Playing](#{track.download_link.gsub(')', '%29')})***"
      embed.thumbnail = { url: config.base_url + track.album_art_path } unless track.album_art_path.nil?
      track.fill_embed(embed)
    end
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
    skip_response = ApiSkipResponse.new(response_hash)

    if skip_response.error?
      return 'You cannot vote to skip the current track more than once.' if /user cannot vote to skip/ === skip_response.error_msg

      'An error occurred, please contact an admin.'
    elsif skip_response.was_track_skipped?
      Thread.new do
        sleep(5)
        track = api_client.get_now_playing
        bot.game = track.artist || '-' unless track.nil?
      end

      'The current track will be skipped shortly.'
    elsif skip_response.current_listeners == 0
      'You cannot skip tracks when no one is listening!'
    else
      "Not enough skip votes yet. #{skip_response.current_skips} Skips / #{skip_response.current_listeners} Listeners"
    end
  end

  def enqueue_track(event, *search_terms)
    query = search_terms.join(' ')
    response_hash = api_client.request_file(event.author.distinct, query)
    enqueue_response = ApiEnqueueResponse.new(response_hash)

    if enqueue_response.multiple_matches?
      "There were multiple matches for your query:\n- #{enqueue_response.suggestions.join("\n- ")}"
    elsif enqueue_response.no_matches?
      'No matches were found for your query.'
    elsif enqueue_response.error?
      'The server encountered an unexpected error.'
    else
      "The requested Track was queued and will play in approximately #{ChronicDuration.output(enqueue_response.seconds_remaining, keep_zero: true)}."
    end
  end

  def enqueue_album(event, *search_terms)
    query = search_terms.join(' ')
    response_hash = api_client.request_folder(event.author.distinct, query)
    enqueue_response = ApiEnqueueResponse.new(response_hash)

    if enqueue_response.multiple_matches?
      "There were multiple matches for your query:\n- #{enqueue_response.suggestions.join("\n- ")}"
    elsif enqueue_response.no_matches?
      'No matches were found for your query.'
    elsif enqueue_response.error?
      'The server encountered an unexpected error.'
    else
      "The requested Album (#{enqueue_response.tracks_enqueued} tracks) was queued and will play in approximately #{ChronicDuration.output(enqueue_response.seconds_remaining, keep_zero: true)}."
    end
  end

  def like_track(_event, *dislike)
    track = api_client.get_now_playing

    global_redis.hsetnx('tracks', track.id, track.to_json)

    dislike_params = %w(dislike unlike -)

    if user_redis.sismember('likes', track.id)
      if dislike.empty?
        'Track is already in your likes!'
      elsif dislike_params.include?(dislike.first.downcase)
        user_redis.srem('likes', track.id)

        'Track removed from your likes.'
      else
        "Parameter must be one of #{dislike_params.join(', ')} if provided."
      end
    else
      user_redis.sadd('likes', track.id)

      'Track added to your likes!'
    end
  end

  def show_likes(_event)
    return 'No Tracks liked yet!' unless user_redis.exists('likes')

    likes = global_redis.hmget('tracks', *user_redis.smembers('likes'))

    "***Liked Tracks***\n\t" + likes.map do |track_json|
      RadioTrack.from_json(track_json).min_print
    end.join("\n\t")
  end

  def clear_likes(_event)
    user_redis.del('likes')
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

  def fill_track_embed(embed)
    embed.title = config.radio_name
    embed.url = config.base_url
    embed.thumbnail = { url: config.splash_image }
    embed.timestamp = Time.now
    embed.color = random_color
  end

  def last_hour
    (Time.now - (60 * 60)).to_i
  end

  def random_color
    '0x%06x' % (rand * 0xffffff)
  end
end