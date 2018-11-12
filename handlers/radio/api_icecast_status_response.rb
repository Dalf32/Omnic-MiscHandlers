# api_icecast_status_response.rb
#
# Author::  Kyle Mullins

require_relative '../../api/http_response'

class ApiIcecastStatusResponse < HttpResponse
  def num_listeners
    body[:current_listeners].to_i
  end

  def running?
    body[:is_running]
  end
end
