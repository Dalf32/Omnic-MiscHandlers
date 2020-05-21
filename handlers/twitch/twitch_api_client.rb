# TwitchApiClient
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/api_client'

class TwitchApiClient < ApiClient
  def initialize(log:, auth_url:)
    super(log: log)

    @auth_url = auth_url
  end

  def get_bearer_token(client_id:, client_secret:)
    request_params = "&client_id=#{client_id}&client_secret=#{client_secret}"
    response = make_post_request(@auth_url + request_params, '')
    response.dig(:response_body, :access_token)
  end
end
