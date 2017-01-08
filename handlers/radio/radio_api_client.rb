# radio_api_client.rb
#
# Author::	Kyle Mullins

require 'open-uri'
require 'json'

require_relative 'radio_track'
require_relative '../../util/hash_util'

class RadioApiClient
  include HashUtil

  def initialize(base_url, endpoints, log)
    @base_url = base_url
    @log = log

    @icecast_endpoint = endpoints[:icecast]
    @mpd_endpoint = endpoints[:mpd]
    @share_endpoint = endpoints[:share]
    @history_current_endpoint = endpoints[:history_current]
    @history_by_date_endpoint = endpoints[:history_by_date]
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

  private

  def make_api_request(api_endpoint, **args)
    arguments = (args.empty? ? '' : '?') + URI.encode_www_form(args)
    request_url = @base_url + api_endpoint + arguments

    @log.debug('Making API request: ' + request_url)
    symbolize_keys(JSON.parse(open(request_url).readlines.join)) || {}
  rescue OpenURI::HTTPError, Errno::ECONNREFUSED => http_err
    @log.error(http_err)
    {}
  end
end