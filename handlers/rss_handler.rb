# RssHandler
#
# AUTHOR::  Kyle Mullins

require 'chronic_duration'
require 'net/http'
require 'rss'

require_relative 'rss/feed_config_store'
require_relative 'rss/rss_feed_config'

class RssHandler < CommandHandler
  feature :rss, default_enabled: false,
          description: 'Posts updates from configured RSS feeds'

  command(:addrss, :add_feed)
    .feature(:rss).no_args.pm_enabled(false).permissions(:manage_channels)
    .usage('addrss')
    .description('Adds a new RSS feed to be monitored, prompting for details.')

  command(:showrssfeeds, :show_feeds)
    .feature(:rss).max_args(1).pm_enabled(false).permissions(:manage_channels)
    .usage('showrssfeeds [verbose]')
    .description('Lists all RSS feeds being monitored.')

  command(:removerss, :remove_feed)
    .feature(:rss).min_args(1).pm_enabled(false)
    .permissions(:manage_channels).usage('removerss <feed name>')
    .description('Removes an RSS feed from monitoring.')

  command(:rssfilterhelp, :filter_help)
    .feature(:rss).no_args.pm_enabled(false).permissions(:manage_channels)
    .usage('rssfilterhelp')
    .description('Displays help text explaining RSS feed filtering.')

  event :ready, :start_monitor_thread

  def config_name
    :rss
  end

  def redis_name
    :rss
  end

  def add_feed(event)
    name = prompt(event.message, 'Enter the name of the RSS feed:')
    return 'No response given, canceling.' if name.nil?
    return 'An RSS feed with that name already exists.' if feed_store.feed_exists?(@server.id, name)

    feed_result = prompt_for_feed(event.message)
    return feed_result.error if feed_result.failure?

    filter_result = prompt_for_filter(event.message)
    return filter_result.error if filter_result.failure?

    channel_name = prompt(event.message, 'Enter the channel where updates should be posted:')
    return 'No response given, canceling.' if channel_name.nil?

    channel_result = find_channel(channel_name)
    return 'Invalid channel.' if channel_result.failure?

    frequency_result = prompt_for_frequency(event.message)
    return frequency_result.error if frequency_result.failure?

    feed_conf = RssFeedConfig.new(
      name: name,
      feed: feed_result.value,
      filter: filter_result.value,
      channel_id: channel_result.value.id,
      frequency: frequency_result.value
    )

    feed_store.add_feed(@server.id, feed_conf)
    'Feed added.'
  end

  def show_feeds(_event, *opt)
    feeds = feed_store.server_feeds(@server.id)
    return 'No RSS feeds configured.' if feeds.empty?

    is_verbose = opt.first&.casecmp?('verbose')

    feeds.map do |feed|
      <<~FEED
        #{feed.name.capitalize} - #{feed.feed}
          Posted to #{bot.channel(feed.channel_id)&.name}
          Updating every #{ChronicDuration.output(feed.frequency)}
          #{is_verbose ? "Filter: #{feed.filter_str}" : ''}
          #{is_verbose ? "Last post ID: #{feed.last_post_id}" : ''}
          #{is_verbose ? "Last updated: #{feed.last_updated_at}" : ''}
      FEED
    end.map(&:strip).join("\n\n")
  end

  def remove_feed(_event, *feed_name)
    feed_name = feed_name.join(' ')
    return 'Invalid feed name.' unless feed_store.feed_exists?(@server.id, feed_name)

    feed_store.remove_feed(@server.id, feed_name)
    'Feed removed.'
  end

  def filter_help(_event)
    <<~HELP
      Feed filters allow you to select which items from the RSS feed are posted by looking for specified values in specified fields.
      If no filter is added for an RSS feed then all items will be posted. If multiple filters are provided then only items matching all of them will be posted.
      They should be formatted as "<field> = <value>", for instance "Category = Changelog".
      Some of the accepted fields are as follows, but not all fields may be populated for all feeds:
      - Title
      - Link
      - Author
      - Category
      - DC_Creator
      - Content_Encoded
      - Comments
    HELP
  end

  def start_monitor_thread(_event)
    thread(:rss_monitor_thread, &method(:monitor_rss_feeds))
  end

  private

  def feed_store
    @feed_store ||= FeedConfigStore.new(global_redis)
  end

  def min_sleep_time
    config.min_sleep_time || 10 * 60 # 10 minutes (in seconds)
  end

  def max_sleep_time
    config.max_sleep_time || 7 * 24 * 60 * 60 # 1 week (in seconds)
  end

  def monitor_rss_feeds
    loop do
      feeds = feed_store.all_feeds
      sleep_time = max_sleep_time

      feeds.each do |feed_conf|
        unless feed_conf.should_update?
          sleep_time = determine_sleep_time(sleep_time, feed_conf.time_to_update)
          next
        end

        channel = bot.channel(feed_conf.channel_id)
        return if channel.nil?

        rss_feed = get_rss_feed(feed_conf)
        filtered_items = feed_conf.remove_posted(
          feed_conf.apply_filter(rss_feed.items))

        if filtered_items.any?
          post_feed_update(channel, feed_conf.name, filtered_items)
          feed_conf.last_post = filtered_items.first
        end

        feed_conf.mark_updated
        feed_store.set_feed(channel.server.id, feed_conf)

        sleep_time = determine_sleep_time(sleep_time, feed_conf.time_to_update)
      end

      sleep_thread(sleep_time)
    rescue StandardError => err
      log.error(err)
    end
  end

  def determine_sleep_time(cur_sleep_time, other_sleep_time)
    return cur_sleep_time if other_sleep_time > cur_sleep_time
    return min_sleep_time if other_sleep_time < min_sleep_time

    other_sleep_time
  end

  def sleep_thread(sleep_time)
    log.debug("Sleeping RSS monitor thread for #{sleep_time}s.")
    sleep(sleep_time)
  end

  def get_rss_feed(feed_conf)
    rss_uri = URI.parse(feed_conf.feed)
    raw_content = Net::HTTP.get(rss_uri)
    RSS::Parser.parse(raw_content)
  end

  def post_feed_update(channel, feed_name, feed_items)
    log.debug("Posting RSS update for #{feed_name}")

    feed_links = format_feed_items(feed_items)
    message = "New posts for #{feed_name.capitalize}:"

    feed_links.each do |link|
      if message.length + link.length > 2_000
        bot.send_message(channel, message)
        message = "New posts for #{feed_name.capitalize} (continued):"
      end

      message += link
    end

    bot.send_message(channel, message)
  end

  def format_feed_items(feed_items)
    if feed_items.length > 5
      feed_links = feed_items.map { |item| "[#{item.title}](<#{item.link}>)" }
    else
      feed_links = feed_items.map(&:link)
    end

    feed_links.map { |link| "\n- #{link}" }
  end

  def prompt(message, prompt_str)
    message.reply(prompt_str)
    @user.await!(timeout: 60)&.text
  end

  def prompt_for_feed(message)
    feed = prompt(message, 'Enter the URL of the RSS feed to monitor:')
    return Result.new(error: 'No response given, canceling.') if feed.nil?
    return Result.new(error: 'URL must have RSS extension.') unless feed.downcase.end_with?('rss')

    begin
      URI.parse(feed)
    rescue URI::InvalidURIError
      return Result.new(error: 'Invalid RSS feed URL.')
    end

    Result.new(value: feed)
  end

  def prompt_for_filter(message)
    filter_hash = {}
    filter = prompt(message, 'Enter the filter to be applied to the RSS feed (command rssfilterhelp for details), or [S]kip:')
    return Result.new(error: 'No response given, canceling.') if filter.nil?

    filter = '' if filter.casecmp?('s') || filter.casecmp?('skip')
    filter_regex = /[a-z_]+ *= *.+/i.freeze

    loop do
      break if filter.empty?
      return Result.new(error: 'Invalid filter.') unless filter_regex.match?(filter)

      filter_parts = filter.split('=').map(&:strip)
      filter_hash[filter_parts.first] = filter_parts.last

      filter = prompt(message, 'Enter an additional filter to be applied to the RSS feed, or [D]one:')
      return Result.new(error: 'No response given, canceling.') if filter.nil?

      break if filter.casecmp?('d') || filter.casecmp?('done')
    end

    Result.new(value: filter_hash)
  end

  def prompt_for_frequency(message)
    frequency_str = prompt(message, 'Enter the frequency with which the RSS feed should be updated (1 hour, 1 day, etc.):')
    return Result.new(error: 'No response given, canceling.') if frequency_str.nil?

    frequency = ChronicDuration.parse(frequency_str)
    return Result.new(error: 'Invalid frequency.') if frequency.nil?

    unless frequency.between?(min_sleep_time, max_sleep_time)
      min_time_str = ChronicDuration.output(min_sleep_time)
      max_time_str = ChronicDuration.output(max_sleep_time)
      message.reply(
        "Note: frequency will be clamped to the configured minimum (#{min_time_str}) and maximum (#{max_time_str})")

      frequency.clamp(min_sleep_time, max_sleep_time)
    end

    Result.new(value: frequency)
  end
end
