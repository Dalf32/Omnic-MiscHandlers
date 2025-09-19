# frozen_string_literal: true

class RaceResults
  def initialize(race_length)
    @race_length = race_length
    @leg_standings = []
    @leg_casts = []
  end

  def race_started?
    @leg_standings.length.positive?
  end
  alias started? race_started?

  def race_complete?
    @leg_standings.length == @race_length
  end
  alias complete? race_complete?

  def current_leg_num
    @leg_standings.count
  end

  def add_leg_standings(leg_standings)
    @leg_standings << leg_standings.map(&:dup)
    @leg_casts << []
  end
  alias << add_leg_standings

  def any?
    @leg_standings.any?
  end

  def first_leg
    @leg_standings.first
  end

  def current_leg
    @leg_standings.last
  end
  alias standings current_leg

  def previous_leg
    @leg_standings[-2]
  end

  def update_current_leg(leg_standings)
    @leg_standings[-1] = leg_standings
  end

  def add_cast(cast_text)
    @leg_casts.last << cast_text
  end

  def casts
    @leg_casts
  end
end
