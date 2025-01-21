# RssFeedConfig
#
# AUTHOR::  Kyle Mullins

class RssFeedConfig
  attr_reader :name, :feed, :channel_id, :frequency,
              :last_post_id, :last_updated_at

  def initialize(name:, feed:, filter:, channel_id:, frequency:,
                 last_post_id: nil, last_updated_at: nil)
    @name = name
    @feed = feed
    @filter = filter
    @channel_id = channel_id
    @frequency = frequency
    @last_post_id = last_post_id

    if last_updated_at.is_a?(Time)
      @last_updated_at = last_updated_at
    elsif !last_updated_at.nil?
      @last_updated_at = Time.at(last_updated_at)
    end
  end

  def apply_filter(feed_items)
    return feed_items if @filter.nil? || @filter.empty?

    feed_items.filter do |item|
      @filter.to_a.all? do |field, target_value|
        value = item.send(field.downcase)
        value = value.content if value.respond_to?(:content)
        value.casecmp?(target_value)
      end
    end
  end

  def remove_posted(feed_items)
    return feed_items if @last_post_id.nil?

    feed_items.take_while { |item| item.guid.content != @last_post_id }
  end

  def should_update?
    return true if @last_updated_at.nil?

    Time.now - @last_updated_at >= @frequency
  end

  def time_to_update
    return 0 if @last_updated_at.nil?

    time_left = @frequency - (Time.now - @last_updated_at)
    time_left.negative? ? 0 : time_left
  end

  def mark_updated
    @last_updated_at = Time.now
  end

  def last_post=(last_posted)
    return if last_posted.nil?

    @last_post_id = last_posted.guid.content
  end

  def filter_str
    @filter.to_a.map { |field, target_value| "#{field} = #{target_value}" }
           .join(', ')
  end

  def to_h
    {
      feed: @feed,
      filter: @filter,
      channel_id: @channel_id,
      frequency: @frequency,
      last_post_id: @last_post_id,
      last_updated_at: @last_updated_at&.to_i
    }
  end
end
