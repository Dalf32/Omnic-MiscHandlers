# api_server_status_response.rb
#
# Author::  Kyle Mullins

require_relative '../../api/http_response'

class ApiServerStatusResponse < HttpResponse
  def ping_status
    body[:status]
  end

  def ping_error?
    !ping_status.casecmp('success').zero?
  end

  def online?
    body[:online]
  end

  def title
    body[:motd]
  end

  def version
    body.dig(:server, :name)
  end

  def current_players
    body.dig(:players, :now)
  end
end
