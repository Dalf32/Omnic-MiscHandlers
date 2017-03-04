# leaderboard_handler.rb
#
# Author::  Kyle Mullins

require_relative 'leaderboard/team'

class LeaderboardHandler < CommandHandler
  feature :leaderboard, default_enabled: false

  command :leaderboard, :show_leaderboard, pm_enabled: false, feature: :leaderboard,
      description: 'Displays the current state of the Team Leaderboard.'
  command :teaminfo, :team_info, min_args: 1, max_args: 1, pm_enabled: false, feature: :leaderboard,
          description: 'Displays info about the named team.'
  command :jointeam, :join_team, min_args: 1, max_args: 1, pm_enabled: false, feature: :leaderboard,
      description: 'Joins you to the named team.'
  command :incrscore, :increment_team_score, min_args: 1, max_args: 2, pm_enabled: false, feature: :leaderboard,
      description: "Increments the named Team's score by the given amount or 1."
  command :addteam, :add_team, pm_enabled: false, feature: :leaderboard,
      description:

  def show_leaderboard(_event)
    table = <<~TABLE
        Team      Members     Score
        ----      -------     -----
      Reginald       0          0
         Fluff       0          0
        Eugene       0          0
    TABLE
    "***Leaderboard***```#{table}```"
  end

  def team_info(_event, team_name)
    team = get_teams.find{ |team| team.name.downcase == team_name.downcase }

    return "There is no Team #{team_name}." if team.nil?

    "***Team #{team.name}***\n\tAbout: #{team.description}\n\tMembers: #{team.members.join(', ')}"
  end

  def join_team(event, team_name)
    team = get_teams.find{ |team| team.name.downcase == team_name.downcase }

    return "There is no Team #{team_name}." if team.nil?

    #TODO: remove user from other teams, you can only be a member of one team at a time!
    #TODO: add user ids in future; using name only for testing
    team.add_member(event.author.display_name)
    team.to_redis(server_redis)

    "#{event.author.display_name} has joined Team #{team.name}!"
  end

  def increment_team_score(_event, team_name, *amount)
    team = get_teams.find{ |team| team.name.downcase == team_name.downcase }

    return "There is no Team #{team_name}." if team.nil?

    incr_amount = 1

    begin
      incr_amount = Integer(amount.first) unless amount.empty?
    rescue ArgumentError
      return 'If provided, second parameter must be an integer.'
    end

    team.score += incr_amount
    team.to_redis(server_redis)

    "Team #{team.name}'s score has been incremented by #{incr_amount}"
  end

  private

  def get_teams
    #TODO: remove class variable, for testing only
    @@teams ||= [
        Team.new('Reginald').tap do |team|
          team.description = "Everyone's favorite thicc cat."
          team.add_member('Dalf32')
        end,
        Team.new('Fluff').tap do |team|
          team.description = 'She may be thin and scruffy, but fuck is she cute.'
          team.add_member('Graburo Bean')
        end,
        Team.new('Eugene').tap do |team|
          team.description = 'A good all-around cat; the Mario of cats.'
          team.add_member('Eksuos')
        end
    ]
  end
end