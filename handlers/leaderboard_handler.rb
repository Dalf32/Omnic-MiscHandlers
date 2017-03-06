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
  #TODO: command :delteam
  #TODO: command :listmembers
  command :jointeam, :join_team, min_args: 2, max_args: 2, pm_enabled: false, feature: :leaderboard,
      description: 'Joins you to the named team.'
  command :incrscore, :increment_team_score, min_args: 2, max_args: 3, pm_enabled: false, feature: :leaderboard,
      description: "Increments the named Team's score by the given amount or 1."

  def redis_name
    :leaderboard
  end

  def list_leaderboards(_event)
    return 'There are no Leaderboards yet!' if leaderboards.empty?

    "Available Leaderboards: #{leaderboards.map{ |board| board.name }.join(', ')}"
  end

  def show_leaderboard(_event, *board_name)
    return 'There are no Leaderboards yet!' if leaderboards.empty?
    return 'There is more than 1 Leaderboard, so you must specify which to show.' if board_name.empty? && leaderboards.count != 1

    leaderboard = board_name.empty? ? leaderboards.first : get_leaderboard(board_name.first)

    return "There is no Leaderboard with the name #{board_name.first}." if leaderboard.nil?

    "***Leaderboard***\n#{leaderboard.name}```#{leaderboard.pretty_print}```"
  end

  def add_leaderboard(_event, board_name)
    leaderboard = get_leaderboard(board_name)

    return "There is already a Leaderboard with the name #{board_name}!" unless leaderboard.nil?

    Board.new(board_name).to_redis(server_redis)

    "Leaderboard '#{board_name}' has been created!"
  end

  def delete_leaderboard(_event, board_name)
    #TODO: delete leaderboard
  end

  def team_info(_event, board_name, team_name)
    leaderboard = get_leaderboard(board_name)

    return "There is no Leaderboard with the name #{board_name}." if leaderboard.nil?

    team = leaderboard.get_team(team_name)

    return "There is no Team #{team_name} in Leaderboard #{leaderboard.name}." if team.nil?

    "***Team #{team.name}***\n\tAbout: #{team.description}\n\tMembers: #{team.members.join(', ')}"
  end

  def add_team(_event, board_name, team_name)
    leaderboard = get_leaderboard(board_name)

    return "There is no Leaderboard with the name #{board_name}." if leaderboard.nil?

    team = leaderboard.get_team(team_name)

    return "There is already a Team #{team_name} in Leaderboard #{leaderboard.name}!" unless team.nil?

    team = Team.new(team_name)
    leaderboard.add_team(team)
    leaderboard.to_redis(server_redis)

    "Team '#{team_name}' has been added to Leaderboard #{leaderboard.name}"
  end

  def join_team(event, board_name, team_name)
    leaderboard = get_leaderboard(board_name)

    return "There is no Leaderboard with the name #{board_name}." if leaderboard.nil?

    team = leaderboard.get_team(team_name)

    return "There is no Team #{team_name}." if team.nil?

    leaderboard.teams.each{ |t| t.remove_member(event.author.id) }
    team.add_member(event.author.id)
    leaderboard.to_redis(server_redis)

    "#{event.author.display_name} has joined Team #{team.name}!"
  end

  def increment_team_score(_event, board_name, team_name, *amount)
    leaderboard = get_leaderboard(board_name)

    return "There is no Leaderboard with the name #{board_name}." if leaderboard.nil?

    team = leaderboard.get_team(team_name)

    return "There is no Team #{team_name}." if team.nil?

    incr_amount = 1

    begin
      incr_amount = Integer(amount.first) unless amount.empty?
    rescue ArgumentError
      return 'If provided, second parameter must be an integer.'
    end

    team.score += incr_amount
    leaderboard.to_redis(server_redis)

    "Team #{team.name}'s score has been incremented by #{incr_amount}"
  end

  private

  def leaderboards
    @leaderboards ||= server_redis.smembers('boards').map{ |board_name| Board.from_redis(server_redis, board_name) }
  end

  def get_leaderboard(board_name)
    leaderboards.find{ |board| board.name.downcase == board_name.downcase }
  end
end