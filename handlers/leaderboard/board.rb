# board.rb
#
# Author::  Kyle Mullins

class Board
  attr_reader :name, :teams

  def initialize(name)
    @name = name
    @teams = []
  end

  def add_team(team)
    return nil if has_team?(team)

    @teams << team
    team
  end

  def remove_team(team_name)
    return nil unless has_team?(team_name)

    get_team(team_name).tap do |team|
      @teams.delete(team)
    end
  end

  def get_team(team_name)
    @teams.find { |team| team.name.casecmp(team_name) }
  end

  def has_team?(team)
    team_name = Team === team ? team.name : team
    !get_team(team_name).nil?
  end

  alias team? has_team?

  def pretty_print
    max_name_len = [*@teams.map { |team| team.name.length }, 4].max
    max_members_len = [*@teams.map { |team| team.members.count.to_s.length }, 7].max
    max_score_len = [*@teams.map { |team| team.score.to_s.length }, 5].max

    name_pad = (max_name_len / 2.0).ceil
    members_pad = (max_members_len / 2.0).ceil
    score_pad = (max_score_len / 2.0).ceil

    row_template = "%#{name_pad}s%-#{name_pad}s  |  %#{members_pad}s%-#{members_pad}s  |  %#{score_pad}s%-#{score_pad}s"
    header_str = format(row_template, 'Te', 'am', 'Memb', 'ers', 'Sco', 're')
    div_str = format(row_template, '--', '--', '----', '---', '---', '--')

    rows_str = @teams.map do |team|
      name_split = team.name.chars.each_slice((team.name.length / 2.0).ceil).to_a
      members_split = team.members.count.to_s.chars.each_slice((team.members.count.to_s.length / 2.0).ceil).to_a
      score_split = team.score_str.chars.each_slice((team.score.to_s.length / 2.0).ceil).to_a

      format(row_template, name_split[0].join, name_split[1..-1].flatten.join,
             members_split[0].join, members_split[1..-1].flatten.join,
             score_split[0].join, score_split[1..-1].flatten.join)
    end

    "#{header_str}\n#{div_str}\n#{rows_str.join("\n")}"
  end

  def delete(redis)
    board_redis = Board.redis_for_board(redis, @name)

    Board.list_teams(board_redis).each { |team_name| get_team(team_name).delete(board_redis) }
    board_redis.del('teams')
    redis.srem('boards', @name)
  end

  def to_redis(redis)
    board_redis = Board.redis_for_board(redis, @name)

    redis.sadd('boards', @name)
    @teams.each { |team| team.to_redis(board_redis) }
    # Delete teams from Redis that are no longer in the Board
    Board.list_teams(board_redis).each { |team_name| Team.delete(board_redis, team_name) unless has_team?(team_name) }
  end

  def self.from_redis(redis, name)
    board_redis = redis_for_board(redis, name)

    Board.new(name).tap do |board|
      list_teams(board_redis).each { |team_name| board.add_team(Team.from_redis(board_redis, team_name)) }
    end
  end

  # Private Class Methods

  def self.redis_for_board(redis, name)
    Redis::Namespace.new("board:#{name}", redis: redis)
  end

  def self.list_teams(board_redis)
    board_redis.smembers('teams')
  end

  private_class_method :redis_for_board, :list_teams
end
