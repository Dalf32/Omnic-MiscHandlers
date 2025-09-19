# frozen_string_literal: true

require_relative 'race_processor'

class StandingsClusterer < RaceProcessor
  def process_leg(race_results)
    clustered_leg = cluster_horses(race_results.current_leg)
    race_results.update_current_leg(clustered_leg)

    next_processor(race_results)
  end

  private

  def cluster_horses(horses)
    clusters = []
    cur_cluster = [horses.first]
    remaining_horses = horses[1..-1]
    cluster_factor = 0.9
    cluster_factor_growth = 0.02

    loop do
      if remaining_horses.empty?
        clusters << cur_cluster
        break
      end

      cluster_distance = cur_cluster.last.distance * cluster_factor
      parts = remaining_horses.partition { |horse| horse.distance >= cluster_distance  }

      if parts.first.empty?
        clusters << cur_cluster
        cur_cluster = [remaining_horses.first]
        remaining_horses = remaining_horses[1..-1]
        cluster_factor -= cluster_factor_growth
        cluster_factor_growth *= 2
      else
        cur_cluster += parts.first
        remaining_horses = parts.last
      end
    end

    clusters
  end
end
