# radio_api_client.rb
#
# Author::	Kyle Mullins

require 'open-uri'
require 'json'
require 'net/http'
require 'digest'

require_relative 'radio_track'
require_relative '../../util/hash_util'

class RadioApiClient
  include HashUtil

  def initialize(public_key:, private_key:, base_url:, icecast:, share:, history_current:, history_by_date:, skip:,
                 file_request:, folder_request:, log:, **_other_args)
    @public_key = public_key
    @private_key = private_key
    @base_url = base_url
    @log = log

    @icecast_endpoint = icecast
    @share_endpoint = share
    @history_current_endpoint = history_current
    @history_by_date_endpoint = history_by_date
    @skip_endpoint = skip
    @file_request_endpoint = file_request
    @folder_request_endpoint = folder_request
  end

  def get_now_playing
    current_hist_hash = make_api_request(@history_current_endpoint)
    return nil if current_hist_hash.nil? || current_hist_hash.empty?

    _, current_track, _, time_stats = current_hist_hash.to_a.flatten
    time_stats = {} if time_stats.nil?

    RadioTrack.new(**current_track[:track],  **time_stats, played_time: current_track[:played_time])
  end

  def get_history(**args)
    history_hash = make_api_request(@history_by_date_endpoint, **args)
    return [] if history_hash.nil?

    history_hash.map do |hist_info|
      RadioTrack.new(**hist_info[:track], played_time: hist_info[:played_time])
    end
  end

  def get_current_listeners
    make_api_request(@icecast_endpoint)[:current_listeners].to_i
  end

  def skip_track(user_distinct)
    json_request = JSON.generate({ on_behalf_of: user_distinct })
    auth = gen_hmac_auth(json_request)

    make_api_post_request(@skip_endpoint, json_request, headers: { authorization: auth })
  end

  def request_file(user_distinct, search_terms)
    enqueue_request(user_distinct, search_terms, @file_request_endpoint)
  end

  def request_folder(user_distinct, search_terms)
    enqueue_request(user_distinct, search_terms, @folder_request_endpoint)
  end

  private

  def enqueue_request(user_distinct, search_terms, endpoint)
    json_request = JSON.generate({ on_behalf_of: user_distinct })
    auth = gen_hmac_auth(json_request)
    uri = endpoint + '/' + URI.escape(search_terms, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))

    make_api_post_request(uri, json_request, headers: { authorization: auth })
  end

  def make_api_request(api_endpoint, **args)
    arguments = (args.empty? ? '' : '?') + URI.encode_www_form(args)
    request_url = @base_url + api_endpoint + arguments

    @log.debug('Making API GET request: ' + request_url)
    symbolize_keys(JSON.parse(open(request_url).readlines.join)) || {}
  rescue OpenURI::HTTPError, Errno::ECONNREFUSED => http_err
    @log.error(http_err)
    {}
  end

  def make_api_post_request(api_endpoint, body, headers: {}, use_ssl: true)
    uri = URI(@base_url + api_endpoint)

    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = use_ssl

    request = build_http_request(uri.path, body, headers)

    @log.debug("Making API POST request: #{uri.to_s}\n#{request.body}")
    response = https.request(request)
    response_body = symbolize_keys(JSON.parse(response.body))

    unless http_success?(response)
      @log.error("Received error code #{response.code}: #{response.message}\n#{response.body}")
    end

    { http_code: response.code, http_message: response.message, response_body: response_body }
  end

  def gen_hmac_auth(json_body)
    hmac_message = "#{json_body}#{json_body.length}#{@private_key}"
    "#{@public_key}:#{Digest::SHA256.hexdigest(hmac_message)}"
  end

  def build_http_request(path, body, headers)
    Net::HTTP::Post.new(path).tap { |request|
      request.body = body
      request.content_type = 'application/json'
      headers.each{ |key, value| request[key] = value }
    }
  end

  def http_success?(response)
    response.code.start_with?('2')
  end
end