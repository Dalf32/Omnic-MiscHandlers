# owl_player.rb
#
# AUTHOR::  Kyle Mullins

class OwlPlayer
  attr_reader :id, :name, :role

  def initialize(id:, name:)
    @id = id
    @name = name
  end

  def basic_info(given_name:, family_name:, home:, country:, role:, number:)
    @real_name = "#{given_name} #{family_name}"
    @home = "#{home}, #{country}"
    @country = country
    @role = role
    @number = number
  end

  def to_s
    str = @name
    str = "*##{@number}* " + str unless @number.nil?
    str += " :flag_#{@country.downcase}:" unless @country.nil?
    str += " *(#{@role})*" unless @role.nil?
    str
  end
end
