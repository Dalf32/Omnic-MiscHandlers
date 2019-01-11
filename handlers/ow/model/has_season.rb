# has_season.rb
#
# AUTHOR::  Kyle Mullins

module HasSeason
  attr_accessor :season

  def season_num
    @season - 2017
  end
end
