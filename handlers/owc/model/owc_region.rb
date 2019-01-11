# owc_region.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../owl/model/identifiable'

class OwcRegion
  include Identifiable

  attr_accessor :abbreviation, :tournament_id

  def to_s
    "#{@name} (#{@abbreviation})"
  end
end
