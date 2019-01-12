# api_players_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/ow_player'

class ApiPlayersResponse < HttpResponse
  def players
    body[:content].map do |player|
      OwPlayer.new(id: player[:id], name: player[:name])
    end
  end

  def full_players
    # TODO: Populate full OwPlayer objects when needed
  end
end
