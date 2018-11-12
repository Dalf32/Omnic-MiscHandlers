# api_client.rb
#
# Author::  Kyle Mullins

require 'open-uri'
require 'json'
require 'net/http'
require 'digest'

require_relative '../util/hash_util'

class ApiClient
  include HashUtil

  def initialize(log:)
    @log = log
  end

  protected

  def make_get_request(api_url, use_ssl: true, **query_args)
    uri = URI(api_url)
    uri.query = URI.encode_www_form(query_args)

    request = build_get_request(uri.request_uri, {})

    @log.debug("Making API GET request: #{uri}")
    make_api_request(uri, request, use_ssl)
  end

  def make_post_request(api_url, body, headers: {}, use_ssl: true)
    uri = URI(api_url)

    request = build_post_request(uri.request_uri, body, headers)

    @log.debug("Making API POST request: #{uri}\n#{request.body}")
    make_api_request(uri, request, use_ssl)
  end

  def make_api_request(uri, request, use_ssl)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = use_ssl

    response = https.request(request)

    unless http_success?(response)
      @log.error("Received error code #{response.code}: #{response.message}\n#{response.body}")
    end

    response_body = symbolize_keys(JSON.parse(response.body))

    { http_code: response.code, http_message: response.message, response_body: response_body }
  end

  def gen_hmac_auth(json_body)
    hmac_message = "#{json_body}#{json_body.length}#{@private_key}"
    "#{@public_key}:#{Digest::SHA256.hexdigest(hmac_message)}"
  end

  def build_get_request(path, headers)
    Net::HTTP::Get.new(path).tap do |request|
      headers.each { |key, value| request[key] = value }
    end
  end

  def build_post_request(path, body, headers)
    Net::HTTP::Post.new(path).tap do |request|
      request.body = body
      request.content_type = 'application/json'
      headers.each { |key, value| request[key] = value }
    end
  end

  def http_success?(response)
    response.code.start_with?('2')
  end
end
