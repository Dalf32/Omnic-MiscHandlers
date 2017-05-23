# radio_api_client.rb
#
# Author::	Kyle Mullins

require_relative '../../api/api_client'
require_relative 'api_current_track_response'
require_relative 'api_history_response'
require_relative 'api_icecast_status_response'
require_relative 'api_enqueue_response'
require_relative 'api_skip_response'

class RadioApiClient < ApiClient
  def initialize(log:, public_key:, private_key:, base_url:, endpoints:)
    super(log: log)

    @public_key = public_key
    @private_key = private_key
    @base_url = base_url
    @endpoints = endpoints
  end

  def get_now_playing
    response_hash = make_get_request(endpoint(:history_current))
    ApiCurrentTrackResponse.new(response_hash)
  end

  def get_history(**args)
    response_hash = make_get_request(endpoint(:history_by_date), **args)
    ApiHistoryResponse.new(response_hash)
  end

  def get_current_listeners
    response_hash = make_get_request(endpoint(:icecast))
    ApiIcecastStatusResponse.new(response_hash)
  end

  def skip_track(user_distinct)
    json_body = JSON.generate(on_behalf_of: user_distinct)
    auth = gen_hmac_auth(json_body)

    response_hash = make_post_request(endpoint(:skip), json_body, headers: { authorization: auth })
    ApiSkipResponse.new(response_hash)
  end

  def request_file(user_distinct, search_terms)
    enqueue_request(user_distinct, search_terms, :file_request)
  end

  def request_folder(user_distinct, search_terms)
    enqueue_request(user_distinct, search_terms, :folder_request)
  end

  def request_by_id(user_distinct, track_id)
    enqueue_request(user_distinct, track_id.to_s, :id_request)
  end

  private

  def endpoint(endpoint_name)
    @base_url + @endpoints[endpoint_name]
  end

  def enqueue_request(user_distinct, search_terms, endpoint)
    json_body = JSON.generate(on_behalf_of: user_distinct)
    auth = gen_hmac_auth(json_body)
    uri = endpoint(endpoint) + '/' + URI.escape(search_terms, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))

    response_hash = make_post_request(uri, json_body, headers: { authorization: auth })
    ApiEnqueueResponse.new(response_hash)
  end
end
