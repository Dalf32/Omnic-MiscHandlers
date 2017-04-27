# leaderboard_handler.rb
#
# Author::  Kyle Mullins

require_relative 'leaderboard/team'
require_relative 'leaderboard/board'

class LeaderboardHandler < CommandHandler
  feature :leaderboard, default_enabled: false

  command :listboards, :list_leaderboards, min_args: 0, max_args: 0, pm_enabled: false, feature: :leaderboard,
      description: 'Lists all leaderboards on this server.'
  command :leaderboard, :show_leaderboard, min_args: 0, max_args: 1, pm_enabled: false, feature: :leaderboard,
      description: 'Displays the current state of the named leaderboard.'
  command :addboard, :add_leaderboard, min_args: 1, max_args: 1, pm_emabled: false, feature: :leaderboard,
      description: 'Adds a new leaderboard'
  command :delboard, :delete_leaderboard, min_args: 1, max_args: 1, pm_enabled: false, feature: :leaderboard,
      required_permissions: [:administrator], description: 'Deletes the named leaderboard.'
  command :teaminfo, :team_info, min_args: 2, max_args: 2, pm_enabled: false, feature: :leaderboard,
      description: 'Displays info about the named team.'
  command :addteam, :add_team, min_args: 2, max_args: 2, pm_enabled: false, feature: :leaderboard,
      description: 'Adds a team with the given name to the leaderboard.'
  command :delteam, :delete_team, min_args: 2, max_args: 2, pm_enabled: false, feature: :leaderboard,
      description: 'Deletes the team with the given name.'
  command :jointeam, :join_team, min_args: 2, max_args: 2, pm_enabled: false, feature: :leaderboard,
      description: 'Joins you to the named team.'
  command :editteam, :edit_team, min_args: 5, pm_enabled: false, feature: :leaderboard,
      description: 'Edits the score or description of the given team.'

  def redis_name
    :leaderboard
  end

  def list_leaderboards(_event)
    return 'There are no Leaderboards yet!' if leaderboards.empty?

    "Available Leaderboards: #{leaderboards.map(&:name).join(', ')}"
  end

  def show_leaderboard(_event, *board_name)
    return 'There are no Leaderboards yet!' if leaderboards.empty?
    return 'There is more than 1 Leaderboard, so you must specify which to show.' if board_name.empty? && leaderboards.count != 1

    leaderboard = board_name.empty? ? leaderboards.first : get_leaderboard(board_name.first)

    return board_not_found(board_name.first) if leaderboard.nil?

    "***Leaderboard***\n#{leaderboard.name}```#{leaderboard.pretty_print}```"
  end

  def add_leaderboard(_event, board_name)
    leaderboard = get_leaderboard(board_name)

    return "There is already a Leaderboard with the name #{board_name}!" unless leaderboard.nil?

    Board.new(board_name).to_redis(server_redis)

    "Leaderboard '#{board_name}' has been created!"
  end

  def delete_leaderboard(_event, board_name)
    leaderboard = get_leaderboard(board_name)
    return board_not_found(board_name) if leaderboard.nil?

    leaderboard.delete(server_redis)
    "Leaderboard '#{board_name}' has been deleted"
  end

  def team_info(_event, board_name, team_name)
    leaderboard, team = get_board_and_team(board_name, team_name)

    return board_not_found(board_name) if leaderboard.nil?
    return team_not_found(leaderboard.name, team_name) if team.nil?

    "***Team #{team.name}***\n\tAbout: #{team.description}\n\tMembers: #{team.members.join(', ')}"
  end

  def add_team(_event, board_name, team_name)
    leaderboard = get_leaderboard(board_name)
    return board_not_found(board_name) if leaderboard.nil?

    team = leaderboard.add_team(Team.new(team_name))
    return "There is already a Team #{team_name} in Leaderboard #{leaderboard.name}!" if team.nil?

    leaderboard.to_redis(server_redis)
    "Team '#{team_name}' has been added to Leaderboard #{leaderboard.name}"
  end

  def delete_team(_event, board_name, team_name)
    leaderboard = get_leaderboard(board_name)
    return board_not_found(board_name) if leaderboard.nil?

    team = leaderboard.remove_team(team_name)
    return team_not_found(leaderboard.name, team_name) if team.nil?

    leaderboard.to_redis(server_redis)
    "Team '#{team_name}' has been removed from Leaderboard #{leaderboard.name}"
  end

  def join_team(event, board_name, team_name)
    leaderboard, team = get_board_and_team(board_name, team_name)

    return board_not_found(board_name) if leaderboard.nil?
    return team_not_found(leaderboard.name, team_name) if team.nil?

    leaderboard.teams.each { |t| t.remove_member(event.author.id) }
    team.add_member(event.author.id)
    leaderboard.to_redis(server_redis)

    "#{event.author.display_name} has joined Team #{team.name}!"
  end

  def edit_team(_event, board_name, team_name, *params)
    leaderboard, team = get_board_and_team(board_name, team_name)

    return board_not_found(board_name) if leaderboard.nil?
    return team_not_found(leaderboard.name, team_name) if team.nil?

    prop_str, op_str, *value_ary = params

    case prop_str.downcase
    when 'score'
      property = 'score'

      begin
        value = Float(value_ary.first)
      rescue ArgumentError
        return 'When modifying Score, the last parameter must be a number'
      end
    when 'descr'
      property = 'description'
      value = "\"#{value_ary.join(' ')}\"" # TODO: split this string at " so the string can't be terminated and other code executed
    else
      return 'Third parameter must be one of Score or Descr'
    end

    case op_str
      when '='
        operator = '='
      when '+'
        operator = '+='
      else
        return "Fourth parameter must be one of '=' or '+'"
    end

    eval("team.#{property} #{operator} #{value}")
    leaderboard.to_redis(server_redis)

    "Team #{team.name} has been modified successfully."
  end

  private

  def leaderboards
    @leaderboards ||= server_redis.smembers('boards').map { |board_name| Board.from_redis(server_redis, board_name) }
  end

  def get_leaderboard(board_name)
    leaderboards.find { |board| board.name.casecmp(board_name) }
  end

  def get_board_and_team(board_name, team_name)
    board = get_leaderboard(board_name)
    team = nil
    team = board.get_team(team_name) unless board.nil?

    [board, team]
  end

  def board_not_found(board_name)
    "There is no Leaderboard with the name #{board_name}."
  end

  def team_not_found(board_name, team_name)
    "There is no Team #{team_name} in Leaderboard #{board_name}."
  end
end
