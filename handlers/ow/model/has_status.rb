# has_status.rb
#
# AUTHOR::  Kyle Mullins

module HasStatus
  PENDING_STATE = 'PENDING'.freeze
  IN_PROGRESS_STATE = 'IN_PROGRESS'.freeze
  CONCLUDED_STATE = 'CONCLUDED'.freeze

  def pending?
    @state == PENDING_STATE
  end

  def in_progress?
    @state == IN_PROGRESS_STATE
  end

  def concluded?
    @state == CONCLUDED_STATE
  end

  alias complete? concluded?
end
