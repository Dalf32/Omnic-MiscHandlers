# frozen_string_literal: true

require 'singleton'
require_relative 'data/name_element'

class NamingRegistrar
  include Singleton

  attr_writer :logger

  def initialize
    @horse_prefixes = []
    @horse_suffixes = []
    @race_prefixes = []
    @race_suffixes = []
    @race_champ_suffixes = []
  end

  def data_size
    @horse_prefixes.size + @horse_suffixes.size + @race_prefixes.size +
      @race_suffixes.size + @race_champ_suffixes.size
  end

  def total_combinations
    singular_horse_names = @horse_prefixes.count(&:singular?)
    combo_horse_prefixes = @horse_prefixes.size - singular_horse_names
    chainable_horse_prefixes = @horse_prefixes.count(&:chainable?)
    chainable_horse_suffixes = @horse_suffixes.count(&:chainable?)

    horse_name_combos = singular_horse_names +
                        chainable_horse_prefixes * combo_horse_prefixes * @horse_suffixes.size +
                        chainable_horse_suffixes * @horse_suffixes.size * combo_horse_prefixes
    race_name_combos = @race_prefixes.size * @race_suffixes.size +
                       @race_prefixes.size * @race_champ_suffixes.size

    [horse_name_combos, race_name_combos]
  end

  def generate_horse_name
    prefix = @horse_prefixes.sample
    return prefix.to_s if prefix.singular?

    suffix = @horse_suffixes.sample

    if prefix.chainable? && rand > 0.5
      prefix += @horse_prefixes.sample
    elsif suffix.chainable? && rand > 0.5
      suffix += @horse_suffixes.sample
    end

    prefix + suffix
  end

  def valid_horse_name?(name, horse_data_store)
    return false if name.nil? || name.empty?
    return false if name.length > HorseracingRules.max_horse_name_length
    return false unless name.split.uniq.length == name.split.length
    return false if horse_data_store.exists?(name)

    true
  end

  def generate_valid_horse_name(horse_data_store)
    tries = 0

    loop do
      tries += 1
      horse_name = generate_horse_name
      return horse_name if valid_horse_name?(horse_name, horse_data_store)

      log("Failed to generate horse name #{tries} times") if tries % 5 == 0
    end
  end

  def generate_race_name(is_championship)
    prefix = @race_prefixes.sample
    suffix = is_championship ? @race_champ_suffixes.sample : @race_suffixes.sample
    [prefix + suffix, suffix.length]
  end

  def valid_race_name?(name, scheduled_races)
    return false if name.nil? || name.empty?
    return false if scheduled_races.any? { |race| race.name.casecmp?(name) }

    true
  end

  def generate_valid_race_name(is_championship, scheduled_races)
    tries = 0

    loop do
      tries += 1
      race_name = generate_race_name(is_championship)
      return race_name if valid_race_name?(race_name, scheduled_races)

      log("Failed to generate race name #{tries} times") if tries % 5 == 0
    end
  end

  def load(horse_names, race_names)
    @horse_prefixes += build_name_elements(horse_names[:prefixes])
    @horse_suffixes += build_name_elements(horse_names[:suffixes])

    @race_prefixes += build_name_elements(race_names[:prefixes])
    @race_suffixes += build_name_elements(race_names[:suffixes])
    @race_champ_suffixes += build_name_elements(race_names[:championship_suffixes])

    log("Horseracing name entries: #{data_size}")
  end

  private

  def build_name_elements(name_data)
    name_data.map { |name_hash| NameElement.new(**name_hash) }
  end

  def log(message)
    return if @logger.nil?

    @logger.info(message)
  end
end
