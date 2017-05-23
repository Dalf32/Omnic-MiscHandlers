# api_history_response.rb
#
# Author::  Kyle Mullins

require_relative '../../api/http_response'

class ApiHistoryResponse < HttpResponse
  def tracks
    body.map do |hist_info|
      RadioTrack.new(**hist_info[:track], played_time: hist_info[:played_time])
    end
  end
end