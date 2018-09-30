# stream.rb
#
# AUTHOR::  Kyle Mullins

class Stream
  attr_reader :name, :login, :game_id, :title
  attr_accessor :game

  def initialize(user_data)
    @name = user_data.display_name
    @login = user_data.login
  end

  def populate(streams_data)
    @is_live = !streams_data.empty?
    return unless live?

    stream_data = streams_data.first
    @game_id = stream_data.game_id
    @title = stream_data.title
  end

  def live?
    @is_live
  end

  def has_game?
    !@game_id.nil?
  end

  def url
    "https://www.twitch.tv/#{@login}"
  end

  def format_message(preamble = '')
    if live?
      message = "#{@name} is live now playing #{@game}"
      message += "\n*#{@title}*"
    else
      message = "#{@name} is currently offline"
    end

    preamble + message + "\n" + url
  end

  def to_s
    str = "#{@name} (#{@login}); live? #{live?}"
    str += "; playing #{@game || @game_id}; title: #{@title}" if live?
    str
  end
end
