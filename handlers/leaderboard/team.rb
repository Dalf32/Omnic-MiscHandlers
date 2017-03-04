# team.rb
#
# Author::  Kyle Mullins

class Team
  attr_reader :name, :description, :members, :score
  attr_writer :description, :score

  def initialize(name)
    @name = name
    @members = []
    @score = 0
  end

  def add_member(member_id)
    @members<<member_id
    @members.uniq!
  end

  def remove_member(member_id)
    @members.delete(member_id)
  end

  def to_redis(redis)
    #TODO: save to redis/update redis entry
  end

  def self.from_redis(redis, name)
    #TODO: create from redis entry
  end
end