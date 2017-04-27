# api_enqueue_response.rb
#
# Author::	Kyle Mullins

require_relative 'http_response'

class ApiEnqueueResponse < HttpResponse
  def seconds_remaining
    body[:seconds_remaining]
  end

  def num_tracks_enqueued
    body[:tracks_enqueued]
  end

  def suggestions
    body[:did_you_mean]
  end

  def tracks
    body[:tracks].map { |track| RadioTrack.new(**track) }
  end

  def error_msg
    body[:error]
  end

  def multiple_matches?
    status_code == 300
  end

  def no_matches?
    status_code == 404
  end
end
