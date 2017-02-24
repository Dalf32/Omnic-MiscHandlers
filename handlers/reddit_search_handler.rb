# reddit_search_handler.rb
#
# Author::	Kyle Mullins

require 'redd'

class RedditSearchHandler < CommandHandler
  command :reddit, :search_reddit

  def config_name
    :reddit
  end

  def search_reddit(_event, *criteria)
    start_time = Time.now.to_i
    subs_split = subs.each_slice(config.subs_per_request).to_a

    reddit = Redd.it(:userless, config.client_id, config.client_secret)

    results = []

    subs_split.shuffle.each do |sub_list|
      puts sub_list.join('+')

      results += reddit.search(criteria.join(' '), sub_list.join('+'), sort: :relevance, limit: 5)
      puts results.count
      break unless results.empty?
    end

    chosen_result = results.sample
    puts chosen_result

    puts "#{Time.now.to_i - start_time}"
    "Criteria: #{criteria.join(' ')}, Sub: #{chosen_result.subreddit}, #{chosen_result.url}"
  end

  private

  def subs
    @@subs ||= open(config.subreddit_list_file).readlines.map{ |s| s.gsub('/r/', '').chomp }
  end
end