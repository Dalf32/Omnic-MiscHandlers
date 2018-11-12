# api_current_track_response.rb
#
# Author::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'radio_track'

class ApiCurrentTrackResponse < HttpResponse
  def track
    time_stats = body[:time_stats] || {}

    RadioTrack.new(**body.dig(:current_track, :track), **time_stats,
                   **body[:current_track].select { |k, _v| %i[played_time on_behalf_of bot_queued].include?(k) })
  end
end
