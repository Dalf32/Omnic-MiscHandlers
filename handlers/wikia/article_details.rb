# article_details.rb
#
# Author::  Kyle Mullins

class ArticleDetails
  attr_reader :id, :title, :url, :summary

  def initialize(id:, title:, url:, summary: '')
    @id = id
    @title = title
    @url = url
    @summary = summary
  end

  def fill_embed(embed)
    embed.description = "[#{@title}](#{@url})\n#{@summary}"
  end
end