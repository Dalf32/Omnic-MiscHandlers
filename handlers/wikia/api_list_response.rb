# api_list_response.rb
#
# Author::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'article_details'

class ApiListResponse < HttpResponse
  def total_results
    body[:total]
  end

  def pages
    body[:batches]
  end

  def current_page
    body[:currentBatch]
  end

  def items
    body[:items].map { |article| ArticleDetails.new(id: article[:id], title: article[:title], url: article[:url]) }
  end

  def no_results?
    status_code == 404
  end
end
