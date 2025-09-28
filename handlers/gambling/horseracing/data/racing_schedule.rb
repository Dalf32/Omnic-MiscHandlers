# frozen_string_literal: true

require_relative 'scheduled_race'

class RacingSchedule
  attr_reader :championship_counter

  def initialize(championship_counter: 0, races: [])
    @championship_counter = championship_counter
    @races = races

    @schedule_size = (HorseracingRules.schedule_display_window / HorseracingRules.schedule_time_range.min.to_f).ceil
  end

  def fill(horses, naming_registrar)
    this_hour = Time.new(Time.now.year, Time.now.month, Time.now.day, Time.now.hour).to_i
    last_race_time = @races.empty? ? this_hour : @races.last.time

    (@schedule_size - @races.count).times.to_a.map do
      @championship_counter += 1

      race = generate_race(naming_registrar)
      populate_race(race, horses)

      last_race_time += rand(HorseracingRules.schedule_time_range) * ONE_HOUR
      scheduled_race = ScheduledRace.new(race: race, time: last_race_time)
      scheduled_race.stable_horses
      create_morning_line(scheduled_race)
      @races << scheduled_race

      @championship_counter %= HorseracingRules.championship_frequency
      scheduled_race
    end
  end

  def upcoming_races
    schedule_window = Time.now + (HorseracingRules.schedule_display_window * ONE_HOUR)
    @races.take_while { |race| Time.at(race.time) <= schedule_window }
  end

  def next_race
    @races.first
  end

  def remove_race
    @races.shift
  end

  def to_s
    upcoming_races.map { |race| "#{race.name} @ #{race.time}" }.join(' - ')
  end

  private

  ONE_HOUR = 60 * 60

  def generate_race(naming_registrar)
    is_championship = @championship_counter == HorseracingRules.championship_frequency
    name, length = naming_registrar.generate_valid_race_name(is_championship, @races)

    Race.new(name: name, length: length, is_championship: is_championship)
  end

  def populate_race(race, horses)
    horses = race.championship? ? horses.sort_by { |horse| horse.record.average_placement } : horses.shuffle
    rand(race.entrant_range).times { |n| race << horses[n] }
  end

  def create_morning_line(race)
    line_cap = 100 + race.horses.count + HorseracingRules.house_take
    race_score = race.horses.map(&:score).sum
    race.entrants.each { |horse| horse.odds = horse.score / race_score * line_cap }
    race.entrants.sort_by!(&:odds).reverse!

    top_half = race.entrants[0..((race.horses.count / 2) - 1)]
    bottom_half = race.entrants[(race.horses.count / 2 * -1)..-1]
    num_opinions = race.horses.count / 4

    num_opinions.times do
      top_half.sample.odds += HorseracingRules.morning_line_opinion * 2
      bottom_half.sample.odds -= HorseracingRules.morning_line_opinion
    end

    race.entrants.sort_by!(&:odds).reverse!
  end
end
