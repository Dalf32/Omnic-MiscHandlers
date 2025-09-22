# frozen_string_literal: true

require_relative '../../../../storage/data_store'

class NewsDataStore < DataStore
  def initialize(global_redis)
    @redis = Redis::Namespace.new('horseracing:news', redis: global_redis)
  end

  def push_news(news_item)
    this_minute = Time.new(Time.now.year, Time.now.month, Time.now.day,
                           Time.now.hour, Time.now.min).to_i
    @redis.rpush(this_minute, news_item)
    @redis.expireat(this_minute, this_minute + news_lifetime)
  end
  alias << push_news

  def get_news
    news_keys = @redis.keys('*')
    news_keys.map do |time_key|
      [time_key, @redis.lrange(time_key, 0, -1)]
    end.to_h
  end

  private

  ONE_HOUR = 60 * 60

  def news_lifetime
    HorseracingRules.schedule_display_window * ONE_HOUR
  end
end
