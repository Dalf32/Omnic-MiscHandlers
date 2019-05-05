# OwStatusHandler
#
# AUTHOR::  Kyle Mullins

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
                                         endpoints: config.owc_endpoints)
  end

  def owl_api_client
    @owl_api_client ||= OwlApiClient.new(log: log, base_url: config.owl_base_url,
                                         endpoints: config.owl_endpoints)
  end

  def check_ow_status
    loop do
      live_data = owl_api_client.get_live_match

      if live_data.live?
        log.debug('OWL is live!')
        set_match_status(live_data.live_match, config.owl_stream)

        sleep_duration = wait_time(live_data)
      else
        sleep_duration = wait_time(live_data)
        live_data = owc_api_client.get_live_match

        if live_data.live?
          log.debug('OWC is live!')
          set_match_status(live_data.live_match, config.owc_stream)

          sleep_duration = wait_time(live_data)
        else
          log.debug('Neither is live.')
          clear_status
          sleep_duration = [sleep_duration, wait_time(live_data)].min
        end
      end

      sleep_duration = [sleep_duration, config.min_sleep_time].max

      log.debug("Sleeping OW Status thread for #{sleep_duration}s.")
      sleep(sleep_duration)
    rescue StandardError => err
      log.error(err)
    end
  end

  def wait_time(live_data)
    if live_data.live?
      time_left = live_data.live_match.time_to_end || 0
    else
      time_left = live_data.time_to_match || 0
      time_left /= 1000
    end

    time_left / 2.5
  end

  def clear_status
    bot.update_status('online', nil, nil, 0, false, 0)
  end

  def set_match_status(match, stream_url)
    time_since_start = DateTime.now - match.start_date
    return clear_status if time_since_start > (config.max_game_time / 24.0)

    bot.update_status('online', match.to_s(include_abbrev: false), stream_url)
  end
end
