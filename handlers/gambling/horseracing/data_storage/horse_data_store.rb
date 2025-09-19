# frozen_string_literal: true

require_relative '../../../../storage/data_store'
require_relative '../data/horse'
require_relative '../data/racing_horse'

class HorseDataStore < DataStore
  def initialize(global_redis)
    @redis = Redis::Namespace.new('horseracing:horses', redis: global_redis)
  end

  def exists?(name)
    @redis.exists?(name.downcase)
  end

  def horse(name)
    retrieve_object(@redis, name.downcase, Horse)
  end

  def save_horse(horse)
    save_object(@redis, horse.name.downcase, horse)
  end

  def horses(horse_names)
    return [] if horse_names.nil? || horse_names.empty?

    retrieve_multiple(@redis, Horse, horse_names.map(&:downcase))
  end

  def save_horses(horses)
    return if horses.nil? || horses.empty?

    save_multiple(@redis, horses.map { |horse| [horse.name.downcase, horse] })
  end

  def racing_horse(race_id, name)
    retrieve_from_hash(@redis, race_key(race_id), name.downcase, RacingHorse).tap do |racing_horse|
      racing_horse.horse = horse(name)
    end
  end

  def save_racing_horse(race_id, racing_horse)
    save_to_hash(@redis, race_key(race_id), racing_horse.name.downcase, racing_horse)
  end

  def race_horses(race_id)
    @redis.hgetall(race_key(race_id)).map do |name, race_horse_json|
      from_json(RacingHorse, race_horse_json).tap do |racing_horse|
        racing_horse.horse = horse(name)
      end
    end
  end

  def save_race_horses(race_id, race_horses)
    @redis.hset(race_key(race_id), race_horses.map { |horse| [horse.name.downcase, to_json(horse)] }.flatten)
  end

  def delete_for_race(race_id)
    @redis.del(race_key(race_id))
  end

  def active_horses
    horses(@redis.smembers(:active))
  end

  def add_active_horse(horse)
    horse = horse.name if horse.respond_to?(:name)
    @redis.sadd(:active, horse.downcase)
  end

  def remove_active_horse(horse)
    horse = horse.name if horse.respond_to?(:name)
    @redis.srem(:active, horse.downcase)
  end

  private

  def race_key(race_id)
    "race:#{race_id}"
  end
end
