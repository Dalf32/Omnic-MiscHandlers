# api_article_response.rb
#
# Author::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'article_details'

class ApiArticleDetailResponse < HttpResponse
  def basepath
    body[:basepath]
  end

  def items
    body[:items].map { |article| ArticleDetails.new(id: article[1][:id], title: article[1][:title],
                                                    url: basepath + article[1][:url], summary: article[1][:abstract]) }
  end

  def no_results?
    items.empty?
  end
end