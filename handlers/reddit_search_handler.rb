# reddit_search_handler.rb
#
# Author::	Kyle Mullins

require 'redd'

class RedditSearchHandler < CommandHandler
  feature :reddit, default_enabled: false

  command :reddit, :search_reddit, description: 'Searches Reddit for the given string and returns a random result.',
          min_args: 1, feature: :reddit, limit: { limit: 20, time_span: 60 }

  def config_name
    :reddit
  end

  def search_reddit(event, *criteria)
    subs_split = subs.shuffle.each_slice(config.subs_per_request).to_a

    chosen_result = subs_split.each do |sub_list|
      begin
        results = reddit.search(criteria.join(' '), sub_list.join('+'), sort: :relevance, limit: config.results_per_request)
        results = results.select{ |e| !e.thumbnail.nil? && e.thumbnail != 'self' } if config.media_only

        break results.sample unless results.empty?
        log.debug('Request returned no results.')
      rescue Redd::Error::ServiceUnavailable => unavail_err
        log.error("Reddit error: #{unavail_err.message}")
        return 'HTTP 503 returned from Reddit API'
      end
    end

    preamble = "#{event.author.display_name} searched for \"#{criteria.join(' ')}\"."
    return "#{preamble} No results were found." unless chosen_result.is_a?(Redd::Objects::Submission)

    "#{preamble} Here's a result from /r/#{chosen_result.subreddit} with the title ***#{chosen_result.title}***\n#{chosen_result.url}"
  end

  def reddit
    @reddit ||= Redd.it(:userless, config.client_id, config.client_secret)
  end

  private

  def subs
    @@subs ||= open(config.subreddit_list_file).readlines.map{ |s| s.gsub('/r/', '').chomp }
  end
end