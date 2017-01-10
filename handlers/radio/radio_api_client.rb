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

  def initialize(public_key:, private_key:, base_url:, icecast:, mpd:, share:, history_current:, history_by_date:, skip:, log:)
    @public_key = public_key
    @private_key = private_key
    @base_url = base_url
    @log = log

    @icecast_endpoint = icecast
    @mpd_endpoint = mpd
    @share_endpoint = share
    @history_current_endpoint = history_current
    @history_by_date_endpoint = history_by_date
    @skip_endpoint = skip
  end

  def get_now_playing
    track_hash = make_api_request(@mpd_endpoint)[:current_track]
    return nil if track_hash.nil?

    RadioTrack.new(**track_hash, uploader: track_hash[:who])
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
    hmac_message = "#{json_request}#{json_request.length}#{@private_key}"
    auth = "#{@public_key}:#{Digest::SHA256.hexdigest(hmac_message)}"

    make_api_post_request(@skip_endpoint, json_request, headers: { authorization: auth })
  end

  private

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

    if http_success?(response)
      symbolize_keys(JSON.parse(response.body))
    else
      @log.error("Received error code #{response.code}: #{response.message}\n#{response.body}")
      {}
    end
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