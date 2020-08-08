# OwStatusHandler
#
# AUTHOR::  Kyle Mullins

require 'googleauth'
require 'google/apis/youtube_v3'
require_relative 'ow/owl_api_client'
require_relative 'ow/owc_api_client'

class OwStatusHandler < CommandHandler
  event :ready, :start_status_thread

  def config_name
    :ow_status
  end

  def start_status_thread(_event)
    thread(:ow_status_thread, &method(:check_ow_status))
  end

  private

  def owc_api_client
    @owc_api_client ||= OwcApiClient.new(log: log, base_url: config.owc_base_url,
                                         endpoints: config.owc_endpoints,
                                         locale: config.locale)
  end

  def owl_api_client
    @owl_api_client ||= OwlApiClient.new(log: log, base_url: config.owl_base_url,
                                         endpoints: config.owl_endpoints,
                                         locale: config.locale)
  end

  def youtube_client
    @youtube_client ||= create_youtube_client
  end

  def create_youtube_client
    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(config.credentials_file),
        scope: Google::Apis::YoutubeV3::AUTH_YOUTUBE_READONLY
    )

    Google::Apis::YoutubeV3::YouTubeService.new.tap do |youtube_service|
      youtube_service.client_options.application_name = config.app_name
      youtube_service.authorization = credentials
    end
  end

  def check_ow_status
    loop do
      live_data = owl_api_client.get_live_match

      if live_data.success? && live_data.live?
        log.debug('ow_status: OWL is live.')
        set_match_status(live_data, owl_stream_url)

        sleep_duration = wait_time(live_data)
      else
        sleep_duration = wait_time(live_data)
        live_data = owc_api_client.get_live_match

        if live_data.success? && live_data.live?
          log.debug('ow_status: OWC is live.')
          set_match_status(live_data, owc_stream_url)

          sleep_duration = wait_time(live_data)
        else
          log.debug('ow_status: neither is live.')
          clear_status
          sleep_duration = [sleep_duration, wait_time(live_data)].min
        end
      end

      sleep_duration = sleep_duration.clamp(config.min_sleep_time,
                                            config.max_sleep_time)
      sleep_thread(sleep_duration)
    rescue StandardError => err
      log.error(err)
      sleep_thread(config.min_sleep_time)
    end
  end

  def wait_time(live_data)
    return 0 if live_data.error?

    if live_data.live?
      time_left = live_data.live_match.time_to_end || 0
    else
      time_left = live_data.time_to_match || 0
      time_left /= 1000
    end

    time_left / 2.5
  end

  def clear_status
    return unless bot.connected?

    clear_bot_status
  end

  def set_match_status(live_data, stream_url)
    return unless bot.connected?

    match = live_data.live_match
    time_since_start = DateTime.now - match.start_date
    return clear_status if time_since_start > (config.max_game_time / 24.0)

    status_str = match.to_s(include_abbrev: false)
    status_str = live_data.live_match_bracket_title if match.teams_blank? && live_data.live_match_has_bracket?
    update_bot_status('online', status_str, stream_url)
  end

  def sleep_thread(sleep_duration)
    log.debug("Sleeping ow_status thread for #{sleep_duration}s.")
    sleep(sleep_duration)
  end

  def owc_stream_url
    return config.owc_stream if config.key?(:owc_stream)

    youtube_stream_url(config.owc_channel_id)
  end

  def owl_stream_url
    return config.owl_stream if config.key?(:owl_stream)

    youtube_stream_url(config.owl_channel_id)
  end

  def youtube_stream_url(channel_id)
    results = youtube_client.list_searches(
        'id', channel_id: channel_id, event_type: 'live', type: 'video')
    video_id = results.items.first.id.video_id
    "https://youtube.com/watch?v=#{video_id}"
  rescue Google::Apis::Error => err
    log.error(err)
    nil
  end
end
