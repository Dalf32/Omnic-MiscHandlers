# board.rb
#
# Author::	Kyle Mullins

class Board
  attr_reader :name, :teams

  def initialize(name)
    @name = name
    @teams = []
  end

  def add_team(team)
    @teams<<team
  end

  def get_team(team_name)
    @teams.find{ |team| team.name.downcase == team_name.downcase }
  end

  def pretty_print
    max_name_len = [*@teams.map{ |team| team.name.length }, 'Team'.length].max
    max_members_len = [*@teams.map{ |team| team.members.count.to_s.length }, 'Members'.length].max
    max_score_len = [*@teams.map{ |team| team.score.to_s.length }, 'Score'.length].max

    name_pad = (max_name_len / 2.0).ceil
    members_pad = (max_members_len / 2.0).ceil
    score_pad = (max_score_len / 2.0).ceil

    row_template = "%#{name_pad}s%-#{name_pad}s  |  %#{members_pad}s%-#{members_pad}s  |  %#{score_pad}s%-#{score_pad}s"
    header_str = row_template % %w(Te am Memb ers Sco re)
    div_str = row_template % %w(-- -- ---- --- --- --)

    rows_str = @teams.map{ |team|
      name_split = team.name.chars.each_slice((team.name.length / 2.0).ceil).to_a
      members_split = team.members.count.to_s.chars.each_slice((team.members.count.to_s.length / 2.0).ceil).to_a
      score_split = team.score.to_s.chars.each_slice((team.score.to_s.length / 2.0).ceil).to_a

      row_template % [name_split[0].join, name_split[1..-1].flatten.join, members_split[0].join,
          members_split[1..-1].flatten.join, score_split[0].join, score_split[1..-1].flatten.join]
    }.join("\n")

    "#{header_str}\n#{div_str}\n#{rows_str}"
  end

  def to_redis(redis)
    board_redis = Board.redis_for_board(redis, @name)

    redis.sadd('boards', @name)
    @teams.each{ |team| team.to_redis(board_redis) }
  end

  def self.from_redis(redis, name)
    board_redis = redis_for_board(redis, name)

    Board.new(name).tap{ |board|
      board_redis.smembers('teams').each{ |team_name| board.add_team(Team.from_redis(board_redis, team_name)) }
    }
  end

  private

  def self.redis_for_board(redis, name)
    Redis::Namespace.new("board:#{name}", redis: redis)
  end
end