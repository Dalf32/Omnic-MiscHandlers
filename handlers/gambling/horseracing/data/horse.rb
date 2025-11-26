# frozen_string_literal: true

require_relative 'racing_horse'
require_relative 'racing_record'

class Horse
  attr_reader :name, :speed, :power, :stamina, :record

  def initialize(name:, speed:, power:, stamina:, career_length:, parent: nil,
                 record: RacingRecord.new)
    @name = name
    @speed = speed
    @power = power
    @stamina = stamina
    @career_length = career_length
    @parent = parent
    @record = record
  end

  def speed_rank
    rank_str(speed_percent)
  end

  def power_rank
    rank_str(power_percent)
  end

  def stamina_rank
    rank_str(stamina_percent)
  end

  def score
    speed_percent + power_percent + stamina_percent
  end

  def retired?
    @record.races_run >= @career_length
  end

  def injure(impact)
    @career_length -= (@career_length * impact).to_i
  end

  def should_breed?
    @record.average_placement <= HorseracingRules.breeding_apl_requirement
  end

  def stable
    RacingHorse.stable(self)
  end

  def breed(name)
    Horse.new(name: name,
              speed: breed_stat(speed, HorseracingRules.speed_range),
              power: breed_stat(power, HorseracingRules.power_range),
              stamina: breed_stat(stamina, HorseracingRules.stamina_range),
              career_length: rand(HorseracingRules.career_length_range),
              parent: @name)
  end

  def self.breed(name)
    Horse.new(name: name, speed: rand(HorseracingRules.speed_range),
              power: rand(HorseracingRules.power_range),
              stamina: rand(HorseracingRules.stamina_range),
              career_length: rand(HorseracingRules.career_length_range))
  end

  def to_table_cols
    [@name, speed_rank, power_rank, stamina_rank] + @record.to_table_cols
  end

  def to_s
    "#{@name} (#{speed_rank}-#{power_rank}-#{stamina_rank}), #{@record}"
  end

  def to_s_detail
    [
      "**#{@name}**",
      "Speed: #{speed_rank}; Power: #{power_rank}; Stamina: #{stamina_rank}",
      @record.to_s_detail('  '),
      "Status: #{retired? ? 'Retired' : 'Active'}",
      "Parentage: #{@parent.nil? ? '*New Breed*' : @parent}"
    ].join("\n  ")
  end

  def eql?(other)
    @name.eql?(other.name)
  end

  def to_hash
    {
      name: @name,
      speed: @speed,
      power: @power,
      stamina: @stamina,
      career_length: @career_length,
      parent: @parent,
      record: @record.to_hash
    }
  end

  def self.from_hash(horse_hash)
    record_hash = horse_hash.delete(:record)
    record = record_hash.nil? ? RacingRecord.new : RacingRecord.from_hash(record_hash)
    Horse.new(record: record, **horse_hash)
  end

  private

  def speed_percent
    calc_percent(@speed, HorseracingRules.speed_range)
  end

  def power_percent
    calc_percent(@power, HorseracingRules.power_range)
  end

  def stamina_percent
    calc_percent(@stamina, HorseracingRules.stamina_range)
  end

  def calc_percent(stat, stat_range)
    (stat - stat_range.min) / (stat_range.max - stat_range.min).to_f
  end

  def rank_str(rank_percent)
    case rank_percent
      when HorseracingRules.s_rank_range
        'S'
      when HorseracingRules.a_rank_range
        'A'
      when HorseracingRules.b_rank_range
        'B'
      when HorseracingRules.c_rank_range
        'C'
      when HorseracingRules.d_rank_range
        'D'
      else
        'F'
    end
  end

  def breed_stat(stat, stat_range)
    (rand(HorseracingRules.breeding_variance) * stat)
      .ceil.clamp(stat_range.min, stat_range.max * 2)
  end
end
