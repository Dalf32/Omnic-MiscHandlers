# feed_config_store.rb
#
# AUTHOR::  Kyle Mullins

require 'json'

require_relative '../../util/hash_util'
require_relative 'rss_feed_config'

class FeedConfigStore
  include HashUtil

  def initialize(global_redis)
    @redis = global_redis
  end

  def all_feeds
    @redis.scan_each(match: server_key('*')).map { |key| key[7..-1] }
          .map { |server_id| server_feeds(server_id) }.flatten
  end

  def server_feeds(server_id)
    @redis.hgetall(server_key(server_id))
          .map { |feed_name, feed_json| RssFeedConfig.new(name: feed_name, **symbolize_keys(JSON.parse(feed_json))) }
  end

  def server_feeds_count(server_id)
    @redis.hlen(server_key(server_id))
  end

  def feed_exists?(server_id, feed_name)
    @redis.hexists(server_key(server_id), feed_name.downcase)
  end

  def set_feed(server_id, feed)
    @redis.hset(server_key(server_id), feed.name.downcase, JSON.generate(feed.to_h))
  end
  alias add_feed set_feed

  def remove_feed(server_id, feed_name)
    @redis.hdel(server_key(server_id), feed_name.downcase)
  end

  private

  def server_key(server_id)
    "server:#{server_id}"
  end
end
