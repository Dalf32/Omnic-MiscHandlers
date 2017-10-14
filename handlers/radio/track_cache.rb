# track_cache.rb
#
# Author::	Kyle Mullins

require 'redis-objects'

require_relative 'radio_track'

class TrackCache
  def initialize(global_redis, user_redis)
    @tracks_store = Redis::HashKey.new([global_redis.namespace, 'tracks'])
    @likes_store = Redis::Set.new([user_redis.namespace, 'likes'])
  end

  def tracks
    @tracks_store.values.map { |track_json| RadioTrack.from_json(track_json) }
  end

  def add_track(track)
    @tracks_store[track.id] = track.to_json unless @tracks_store.key?(track.id)
  end

  def remove_track(track_id)
    remove_from_likes(track_id)
    @tracks_store.delete(track_id)
    # TODO: Remove from users' likes?
  end

  def liked?(track_id)
    @likes_store.include?(track_id)
  end

  def add_to_likes(track)
    add_track(track)
    @likes_store.add(track.id)
  end

  def remove_from_likes(track_id)
    @likes_store.delete(track_id)
  end

  def liked_tracks
    likes = @likes_store.members
    @tracks_store.bulk_values(*likes).map { |track_json| RadioTrack.from_json(track_json) }
  end

  def likes_count
    @likes_store.count
  end

  def likes_empty?
    @likes_store.empty?
  end

  def clear_likes
    @likes_store.clear
  end
end