# reddit_search_handler.rb
#
# Author::	Kyle Mullins

require 'redd'
require 'concurrent'
require 'net/http'

class RedditSearchHandler < CommandHandler
  feature :reddit, default_enabled: false

  command(:reddit, :search_reddit)
    .min_args(1).feature(:reddit).limit(limit: 20, span: 60)
    .usage('reddit <criteria>')
    .description('Searches Reddit for the given string and returns a random result.')

  def config_name
    :reddit
  end

  def search_reddit(event, *criteria)
    subs_split = subs.shuffle.each_slice(config.subs_per_request).to_a

    found_results_latch = Concurrent::CountDownLatch.new
    request_complete_latch = Concurrent::CountDownLatch.new(subs_split.length)
    search_complete_latch = Concurrent::CountDownLatch.new

    futures = subs_split.map do |sub_list|
      Concurrent::Future.execute(pool: thread_pool) do
        begin
          results = reddit.subreddit(sub_list.join('+'))
                          .search(criteria.join(' '), sort: :relevance, limit: config.results_per_request)
          results = results.select { |r| !r.thumbnail.nil? && r.thumbnail != 'self' } if config.media_only
          results = results.select { |r| url_target_exists?(r.url) }

          if results.empty?
            Concurrent.log(:debug, 'Request returned no results.')
            nil
          else
            found_results_latch.count_down
            results.sample
          end
        rescue HTTP::TimeoutError => timeout
          Concurrent.log(:error, "Reddit error: #{timeout.response.body}")
          nil
        ensure
          request_complete_latch.count_down
        end
      end
    end

    event.channel.start_typing

    [found_results_latch, request_complete_latch].each do |latch|
      Concurrent::Future.execute do
        latch.wait
        search_complete_latch.count_down
      end
    end

    search_complete_latch.wait
    thread_pool.shutdown

    found_results_latch.count_down
    (0..request_complete_latch.count).each { request_complete_latch.count_down }

    completed_future = futures.find { |future| future.fulfilled? && !future.value.nil? }

    preamble = "#{event.author.display_name} searched for \"#{criteria.join(' ')}\"."
    return "#{preamble} No results were found." if completed_future.nil?

    result = completed_future.value
    "#{preamble} Here's a result from /r/#{result.subreddit.to_h[:display_name]} with the title ***#{result.title}***\n#{result.url}"
  end

  def initialize(*_args)
    super

    Concurrent.global_logger = lambda { |level, message, *_log_args|
      log.add(Logging.level_num(level), message)
    }
  end

  private

  def reddit
    @reddit ||= create_reddit_client
  end

  def subs
    @@subs ||= open(config.subreddit_list_file).readlines.map { |s| s.gsub('/r/', '').chomp }
  end

  def thread_pool
    @thread_pool ||= Concurrent::FixedThreadPool.new(config.concurrent_requests)
  end

  def create_reddit_client
    Redd.it(client_id: config.client_id, secret: config.client_secret).tap do |reddit|
      reddit.client.max_retries = 1
    end
  end

  def url_target_exists?(url)
    request_uri = URI(url)
    http = Net::HTTP.new(request_uri.host, request_uri.port)
    response = http.head(request_uri.request_uri)

    response.code.start_with?('2')
  end
end

class Redd::APIClient
  attr_accessor :max_retries
end
