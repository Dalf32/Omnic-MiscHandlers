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
        results = reddit.subreddit(sub_list.join('+')).search(criteria.join(' '), sort: :relevance, limit: config.results_per_request)
        results = results.select{ |e| !e.thumbnail.nil? && e.thumbnail != 'self' } if config.media_only

        break results.sample unless results.empty?
        log.debug('Request returned no results.')
      rescue Redd::ServerError => server_err
        log.error("Reddit error: #{server_err.response.body}")
        return "HTTP #{server_err.response.code} returned from Reddit API"
      end
    end

    preamble = "#{event.author.display_name} searched for \"#{criteria.join(' ')}\"."
    return "#{preamble} No results were found." unless chosen_result.is_a?(Redd::Models::Submission)

    "#{preamble} Here's a result from /r/#{chosen_result.subreddit.to_h[:display_name]} with the title ***#{chosen_result.title}***\n#{chosen_result.url}"
  end

  def reddit
    @reddit ||= Redd.it(client_id: config.client_id, secret: config.client_secret)
  end

  private

  def subs
    @@subs ||= open(config.subreddit_list_file).readlines.map{ |s| s.gsub('/r/', '').chomp }
  end
end