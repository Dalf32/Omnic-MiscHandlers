# team.rb
#
# Author::  Kyle Mullins

class Team
  attr_reader :name, :description, :members, :score
  attr_writer :description, :score

  def initialize(name)
    @name = name
    @members = []
    @description = ''
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
    team_redis = Team.redis_for_team(redis, @name)

    redis.sadd('teams', @name)
    team_redis.set('description', @description)
    team_redis.set('score', @score)
    team_redis.del('members')
    team_redis.sadd('members', *@members) unless @members.empty?
  end

  def self.from_redis(redis, name)
    team_redis = redis_for_team(redis, name)

    Team.new(name).tap{ |team|
      team_redis.smembers('members').each{ |member_id| team.add_member(member_id) }
      team.description = team_redis.get('description')
      team.score = team_redis.get('score')
    }
  end

  private

  def self.redis_for_team(redis, name)
    Redis::Namespace.new("team:#{name}", redis: redis)
  end
end