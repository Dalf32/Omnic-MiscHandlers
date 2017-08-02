# minecraft_status_client.rb
#
# Author::  Kyle Mullins

require_relative '../../api/api_client'
require_relative 'api_server_status_response'

class MinecraftStatusClient < ApiClient
  def initialize(log:, base_url:, status_endpoint:)
    super(log: log)

    @base_url = base_url
    @status_endpoint = status_endpoint
  end

  def get_server_status(server_url)
    response_hash = make_get_request(@base_url + @status_endpoint, use_ssl: true, ip: server_url)
    ApiServerStatusResponse.new(response_hash)
  end
end
