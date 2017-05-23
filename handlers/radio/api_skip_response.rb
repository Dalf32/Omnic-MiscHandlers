# api_skip_response.rb
#
# Author::	Kyle Mullins

require_relative '../../api/http_response'

class ApiSkipResponse < HttpResponse
  def error_msg
    body[:error]
  end

  def current_listeners
    body[:current_listeners].to_i
  end

  def current_skips
    body[:current_skips]
  end

  def was_track_skipped?
    body[:current_skip_percentage] >= body[:skip_percentage_threshold]
  end
end
