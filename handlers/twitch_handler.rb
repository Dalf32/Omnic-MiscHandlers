# twitch_handler.rb
#
# Author::  Kyle Mullins

require 'twitch-api'
require_relative 'twitch/stream'

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
    .permissions(:manage_server).usage('managestreams [option] [argument]')
    .description('Used to manage stream announcements. Try the "help" option for more details.')

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

    get_stream_data(stream_username(user)).format_message
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

    return "There is no channel called #{twitch_name}" if stream_data.nil?

    stream_data.format_message
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
      update_stream_announce_level(args[1])
    when 'channel'
      return 'Name of Channel is required' if args.size == 1
      update_stream_announce_channel(args[1])
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

    count = 0
    stream_data = loop do
      return if count == 5
      count += 1

      stream_data = get_stream_data(stream_username(event.user))
      break stream_data if stream_data.live?

      log.debug("Twitch doesn't think the stream is live yet, sleeping for a bit then retrying.")
      sleep(30)
    end

    return if get_cached_title(event.user) == stream_data.title

    preamble = announce_preamble(reannounce?(event.user))
    message = stream_data.format_message(preamble)
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

  def stream_username(user)
    user.stream_url.split('/').last
  end

  def manage_stream_user(user, action)
    found_user = find_user(user)

    return found_user.error if found_user.failure?

    if action == :add
      server_redis.sadd(:announce_users, found_user.value.id)
      "Stream announcements are now enabled for #{found_user.value.display_name}"
    elsif action == :remove
      server_redis.srem(:announce_users, found_user.value.id)
      "Stream announcements are now disabled for #{found_user.value.display_name}"
    end
  end

  def cache_stream_title(user)
    cache_key = cache_key(user.id)
    server_redis.set(cache_key, user.game)
    server_redis.expire(cache_key, 86_400) # Set to expire in 24 hours just in case
  end

  def get_cached_title(user)
    server_redis.get(cache_key(user.id))
  end

  def reannounce?(user)
    server_redis.exists(cache_key(user.id))
  end

  def cache_key(user_id)
    "stream_cache:#{user_id}"
  end

  def announce_preamble(is_reannounce = false)
    level = server_redis.get(:announce_level)
    level = [0, level.to_i - 1].max.to_s if is_reannounce

    case level
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
    log.debug("Retrieving stream data for: #{channel_name}")
    stream_data = get_basic_stream_data(channel_name)
    return nil if stream_data.nil?

    get_full_stream_data(stream_data)

    log.debug("  #{stream_data}")
    stream_data
  end

  def get_basic_stream_data(channel_name)
    user_result = twitch_client.get_users(login: channel_name)
    return nil if user_result.data.empty?

    Stream.new(user_result.data.first)
  end

  def get_full_stream_data(stream_data)
    streams_result = twitch_client.get_streams(user_login: stream_data.login)
    stream_data.populate(streams_result.data)

    return unless stream_data.has_game?
    stream_data.game = get_twitch_game(stream_data.game_id)
  end

  def get_twitch_game(game_id)
    twitch_client.get_games(id: game_id).data.first.name
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
      help - Displays this help text
      add <user> - Enables stream announcements for the given user
      remove <user> - Disables stream announcements for the given user
      level <level> - Sets the mention level of stream announcements: 0, none = no mention; 1, here = @ here; 2, everyone = @ everyone
      channel <channel> - Sets the channel for stream announcements
      disable - Disables stream announcements
    HELP
  end

  def update_stream_announce_level(level)
    message = case level
              when '0', 'none'
                level = 0
                'Stream announcements will no longer mention users.'
              when '1', 'here'
                level = 1
                'Stream announcements will now include an @ here mention.'
              when '2', 'everyone'
                level = 2
                'Stream announcements will now include an @ everyone mention.'
              else
                return 'Invalid level.'
              end

    server_redis.set(:announce_level, level)
    message
  end

  def update_stream_announce_channel(channel)
    found_channel = find_channel(channel)

    return found_channel.error if found_channel.failure?

    server_redis.set(:announce_channel, found_channel.value.id)

    "Stream announcement channel has been set to #{found_channel.value.mention}"
  end

  def disable_stream_announcements
    server_redis.del(:announce_channel)
    'Stream announcements have been disabled.'
  end
end