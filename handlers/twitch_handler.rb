# twitch_handler.rb
#
# Author::  Kyle Mullins

require 'twitch-api'

class TwitchHandler < CommandHandler
  feature :twitch, default_enabled: true

  command(:live, :live)
    .feature(:twitch).max_args(0).usage('live')
    .description("Announces that you're live and links your stream.")

  command(:whoslive, :show_live_users)
    .feature(:twitch).max_args(0).pm_enabled(false).usage('whoslive')
    .description('Lists which users in this server are live.')

  command(:twitch, :link_twitch)
    .feature(:twitch).args_range(1, 1).usage('twitch <twitch_name>')
    .description('Links the given Twitch stream.')

  command(:managestreams, :manage_streams)
    .feature(:twitch).args_range(0, 2).pm_enabled(false)
    .usage('managestreams [option] [argument]')
    .description('Used to manage stream announcements. Try the "help option for more details."')

  event(:playing, :on_playing_status_change).feature(:twitch)

  def redis_name
    :twitch
  end

  def config_name
    :twitch
  end

  def live(event)
    user = event.author

    return "Doesn't look like you're live... Make sure you've linked your Twitch account to Discord." unless streaming?(user)

    stream_announce_message(user)
  end

  def show_live_users(event)
    live_users_list = live_users(event.server)

    return 'No one is live at the moment.' if live_users_list.empty?

    preamble_str = "There are currently #{live_users_list.length} users live"
    preamble_str = 'There is currently 1 user live' if live_users_list.length == 1

    preamble_str + "\n" +
      live_users_list.map { |user| "#{user.display_name}: <#{user.stream_url}>" }
      .join("\n")
  end

  def link_twitch(_event, twitch_name)
    stream_data = get_stream_data(twitch_name)

    return "There is no channel called #{twitch_name}" if stream_data.empty?

    if stream_data[:is_live]
      response = "#{stream_data[:name]} is live now playing #{stream_data[:game]}"
      response += "\n*#{stream_data[:title]}*"
    else
      response = "#{stream_data[:name]} is currently offline"
    end

    response + "\nhttps://www.twitch.tv/#{stream_data[:name]}"
  end

  def manage_streams(_event, *args)
    return manage_streams_summary if args.empty?

    case args.first
    when 'help'
      manage_streams_help
    when 'add', 'remove'
      return 'Name of User is required' if args.size == 1
      manage_stream_user(args[1], args.first.to_sym)
    when 'level'
      return 'Announcement level is required' if args.size == 1
      set_stream_announce_level(args[1])
    when 'channel'
      return 'Name of Channel is required' if args.size == 1
      set_stream_announce_channel(event.server.name, args[1])
    when 'disable'
      disable_stream_announcements
    else
      'Invalid option.'
    end
  end

  def on_playing_status_change(event)
    return unless [0, 1].include?(event.type)
    return unless announcements_enabled?
    return unless announce_enabled_for_user?(event.user)

    unless event.type == 1
      server_redis.del(cache_key(event.user.id))
      return
    end

    return if get_cached_title(event.user) == event.user.game

    member = event.server.member(event.user.id)
    message = stream_announce_message(member, get_announce_preamble)
    announce_channel.send_message(message)
    cache_stream_title(event.user)
  end

  private

  def streaming?(user)
    stream_type = user.stream_type.nil? ? 0 : user.stream_type
    stream_type = stream_type.is_a?(String) ? stream_type.to_i : stream_type

    stream_type.positive?
  end

  def live_users(server)
    server.online_members(include_idle: false, include_bots: false)
          .select { |user| streaming?(user) }
  end

  def announcements_enabled?
    server_redis.exists(:announce_channel)
  end

  def announce_enabled_for_user?(user)
    server_redis.sismember(:announce_users, user.id)
  end

  def announce_channel
    channel_id = server_redis.get(:announce_channel)
    bot.channel(channel_id, @server)
  end

  def stream_announce_message(user, preamble = '@here ')
    message = "#{preamble}#{user.display_name} is live now! Check them out: #{user.stream_url}"
    message += "\n*#{user.game}*" unless user.game.nil?
    message
  end

  def find_user(username)
    if username.include?('#')
      @server.members.find_all { |member| member.distinct == username }
    else
      @server.members.find_all do |member|
        member.nick&.casecmp(username.downcase)&.zero? ||
          member.username.casecmp(username.downcase).zero?
      end
    end
  end

  def manage_stream_user(user, action)
    users = find_user(user)

    return "#{user} does not match any members of this server" if users.empty?
    return "#{user} matches multiple members of this server" if users.count > 1

    if action == :add
      server_redis.sadd(:announce_users, users.first.id)
      action_str = 'enabled'
    elsif action == :remove
      server_redis.srem(:announce_users, users.first.id)
      action_str = 'disabled'
    else
      return
    end

    "Stream announcements are now #{action_str} for #{users.first.display_name}"
  end

  def cache_stream_title(user)
    cache_key = cache_key(user.id)
    server_redis.set(cache_key, user.game)
    server_redis.expire(cache_key, 86_400) # Set to expire in 24 hours just in case
  end

  def get_cached_title(user)
    server_redis.get(cache_key(user.id))
  end

  def cache_key(user_id)
    "stream_cache:#{user_id}"
  end

  def get_announce_preamble
    case server_redis.get(:announce_level)
    when '0'
      ''
    when '1'
      '@here '
    when '2'
      '@everyone '
    else
      '@here '
    end
  end

  def twitch_client
    @twitch_client ||= Twitch::Client.new(client_id: config.client_id)
  end

  def get_stream_data(channel_name)
    user_result = twitch_client.get_users(login: channel_name)
    return {} if user_result.data.empty?

    stream_data = { name: user_result.data.first.display_name }
    streams_result = twitch_client.get_streams(user_login: channel_name)
    stream_data[:is_live] = !streams_result.data.empty?

    if stream_data[:is_live]
      stream = streams_result.data.first
      stream_data[:game] = get_twitch_game(stream.game_id).name
      stream_data[:title] = stream.title
    end

    stream_data
  end

  def get_twitch_game(game_id)
    twitch_client.get_games(id: game_id).data.first
  end

  def manage_streams_summary
    return 'Stream announcements are disabled, set an announcement channel to enable' unless announcements_enabled?

    response = "Stream announcement channel: #{announce_channel.mention}"
    response += "\nAnnouncement level: #{server_redis.get(:announce_level)}"

    users = server_redis.smembers(:announce_users).map { |id| @server.member(id) }
    response + "\nUsers: #{users.map(&:display_name).join(', ')}"
  end

  def manage_streams_help
    <<~HELP
      help - displays this help text
      add <user> - Enables stream announcements for the given user
      remove <user> - Disables stream announcements for the given user
      level <level> - Sets the mention level of stream announcements: 0 = no mention, 1 = @ here, 2 = @ everyone
      channel <channel> - Sets the channel for stream announcements
      disable - Disables stream announcements
    HELP
  end

  def set_stream_announce_level(level)
    message = case level
              when '0'
                'Stream announcements will no longer mention users.'
              when '1'
                'Stream announcements will now include an @ here mention.'
              when '2'
                'Stream announcements will now include an @ everyone mention.'
              else
                return 'Invalid level.'
              end

    server_redis.set(:announce_level, level)
    message
  end

  def set_stream_announce_channel(server_name, *channel)
    channels = bot.find_channel(channel.first, server_name, type: 0)

    return "#{channel} does not match any channels on this server" if channels.empty?
    return "#{channel} matches more than one channel on this server" if channels.count > 1

    server_redis.set(:announce_channel, channels.first.id)

    "Stream announcement channel has been set to #{channels.first.mention}"
  end

  def disable_stream_announcements
    server_redis.del(:announce_channel)
    'Stream announcements have been disabled.'
  end
end