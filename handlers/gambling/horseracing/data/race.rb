# frozen_string_literal: true

class Race
  attr_accessor :id, :running
  attr_reader :name, :length, :horses

  def initialize(id: 0, name:, length:, is_championship:, running: 0, horse_names: [])
    @id = id
    @name = name
    @length = length
    @is_championship = is_championship
    @running = running
    @horse_names = horse_names # only used for deserialization

    @horses = []
  end

  def championship?
    @is_championship
  end

  def entrant_range
    championship? ? HorseracingRules.championship_entrant_range : HorseracingRules.race_entrant_range
  end

  def add_horse(horse)
    @horses << horse
    @horses.sort_by!(&:score).reverse!
  end
  alias << add_horse

  def record_results(results)
    sorted_horses = []
    results.standings.flatten.each.with_index do |entrant, placement|
      horse = @horses.find { |h| h.eql?(entrant) }
      horse.record.add_result(placement + 1)
      sorted_horses << horse
    end

    @horses = sorted_horses
  end

  def race_str(horses)
    "#{to_s_short} (#{@length * 2} furlongs)\n  #{horses.join("\n  ")}"
  end

  def to_s
    race_str(@horses)
  end

  def to_s_short
    running_str = @running == 1 ? '' : " (#{ordinal_indicator_str(@running)} running)"
    name + running_str
  end

  def each_horse_name(&block)
    @horse_names.each(&block)
  end

  def to_hash
    {
      id: @id,
      name: @name,
      length: @length,
      is_championship: @is_championship,
      running: @running,
      horse_names: @horses.map(&:name)
    }
  end

  def self.from_hash(race_hash)
    Race.new(**race_hash)
  end

  private

  def ordinal_indicator_str(number)
    return "#{number}th" if (11..13).include?(number.abs % 100)

    number.to_s + case number.abs % 10
      when 1
        'st'
      when 2
        'nd'
      when 3
        'rd'
      else
        'th'
    end
  end
end
