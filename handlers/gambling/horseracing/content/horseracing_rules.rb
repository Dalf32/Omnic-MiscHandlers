# frozen_string_literal: true

require 'configatron/core'

HorseracingRules = Configatron::RootStore.new

HorseracingRules.speed_range = 30..100
HorseracingRules.power_range = 5..20
HorseracingRules.stamina_range = 2..12
HorseracingRules.career_length_range = 10..60 # num races
HorseracingRules.race_entrant_range = 6..12
HorseracingRules.championship_entrant_range = 12..20
HorseracingRules.race_day_variance = 0.85..1.15
HorseracingRules.schedule_display_window = 24 # in hours
HorseracingRules.schedule_time_range = 3..12 # in hours
HorseracingRules.championship_frequency = 10 # num races between championships
HorseracingRules.breeding_variance = 0.75..1.25
HorseracingRules.offspring_range = 1..4
HorseracingRules.breeding_apl_requirement = 3
HorseracingRules.max_horse_name_length = 18 # includes spaces
HorseracingRules.min_active_horses = 35
HorseracingRules.odds_map = [['4-5', 4 / 5.0, 55], ['1-1', 1, 50],
                             ['6-5', 6 / 5.0, 45], ['7-5', 7 / 5.0, 42],
                             ['8-5', 8 / 5.0, 38], ['9-5', 9 / 5.0, 35],
                             ['2-1', 2, 33], ['5-2', 5 / 2.0, 28],
                             ['3-1', 3, 25], ['7-2', 7 / 2.0, 22],
                             ['4-1', 4, 20], ['9-2', 9 / 2.0, 18],
                             ['5-1', 5, 16], ['6-1', 6, 14], ['8-1', 8, 11],
                             ['10-1', 10, 9], ['12-1', 12, 7], ['15-1', 15, 6],
                             ['20-1', 20, 4], ['30-1', 30, 2], ['50-1', 50, 1]]
HorseracingRules.s_rank_range = 0.9..2.0
HorseracingRules.a_rank_range = 0.8..0.9
HorseracingRules.b_rank_range = 0.65..0.8
HorseracingRules.c_rank_range = 0.5..0.65
HorseracingRules.d_rank_range = 0.35..0.5
HorseracingRules.injury_chance = 0.05
HorseracingRules.injury_speed = 10
HorseracingRules.injury_map = [[1, 'career-ending'], [0.4, 'severe'],
                               [0.25, 'serious'], [0.25, 'serious'],
                               [0.2, 'major'], [0.2, 'major'], [0.2, 'major'],
                               [0.1, 'moderate'], [0.1, 'moderate'],
                               [0.1, 'moderate'], [0.1, 'moderate'],
                               [0.05, 'minor'], [0.05, 'minor'], [0.05, 'minor'],
                               [0.05, 'minor']]
