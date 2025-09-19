# frozen_string_literal: true

require_relative '../../../../storage/data_store'
require_relative '../data/race'
require_relative '../data/scheduled_race'
require_relative '../data/racing_schedule'

class RaceDataStore < DataStore
  def initialize(global_redis, horse_data_store)
    @redis = Redis::Namespace.new('horseracing:races', redis: global_redis)
    @horse_data_store = horse_data_store
  end

  def new_race_id
    @redis.incr(:race_id)
  end

  def race(id)
    retrieve_object(@redis, id, Race).tap do |race|
      race.each_horse_name { |horse_name| race << @horse_data_store.horse(horse_name) }
    end
  end

  def save_race(race)
    if race.id.zero?
      race.id = new_race_id
      race.running = @redis.hincrby(:running, race.name, 1)
    end

    save_object(@redis, race.id, race)
  end

  def schedule
    return RacingSchedule.new unless @redis.exists?(:schedule)

    sched_races = @redis.lrange(:schedule, 0, -1).map do |sched_race_json|
      from_json(ScheduledRace, sched_race_json).tap do |sched_race|
        sched_race.race = race(sched_race.race_id)
        sched_race.stable_horses(@horse_data_store.race_horses(sched_race.race_id))
      end
    end

    RacingSchedule.new(championship_counter: @redis.get(:championship_counter).to_i,
                       races: sched_races)
  end

  def save_scheduled_race(race_index, scheduled_race)
    @redis.lset(:schedule, race_index, to_json(scheduled_race))
  end

  def pop_next_race
    from_json(ScheduledRace, @redis.lpop(:schedule)).tap do |sched_race|
      sched_race.race = race(sched_race.race_id)
      sched_race.stable_horses(@horse_data_store.race_horses(sched_race.race_id))
    end
  end

  def push_race(scheduled_race)
    @redis.rpush(:schedule, to_json(scheduled_race))
  end

  def championship_counter=(championship_counter)
    @redis.set(:championship_counter, championship_counter)
  end
end
