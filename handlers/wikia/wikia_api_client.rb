# wikia_api_client.rb
#
# Author::  Kyle Mullins

require_relative '../../api/api_client'
require_relative 'api_list_response'
require_relative 'api_article_detail_response'

class WikiaApiClient < ApiClient
  def initialize(log:, basepath_pattern:, endpoints:)
    super(log: log)

    @basepath_pattern = basepath_pattern
    @endpoints = endpoints
  end

  def search(wiki_name, search_terms, limit: 3)
    response_hash = make_get_request(endpoint(wiki_name, :search), query: search_terms, limit: limit)
    ApiListResponse.new(response_hash)
  end

  def get_article_details(wiki_name, *article_ids)
    response_hash = make_get_request(endpoint(wiki_name, :article_details), ids: article_ids)
    ApiArticleDetailResponse.new(response_hash)
  end

  def wiki_url(wiki_name)
    @basepath_pattern % { wiki_name: wiki_name }
  end

  private

  def endpoint(wiki_name, endpoint_name)
    wiki_url(wiki_name) + @endpoints[endpoint_name]
  end
end