# twitch_handler.rb
#
# Author::  Kyle Mullins

require 'twitch-api'
require_relative 'twitch/stream'
require_relative 'twitch/announce_store'
require_relative 'twitch/user_stream_store'
require_relative 'twitch/twitch_api_client'

class TwitchHandler < CommandHandler
  feature :twitch, default_enabled: true,
                   description: 'Announce when streams are live.'

  command(:live, :live)
    .feature(:twitch).no_args.usage('live')
    .description("Announces that you're live and links your stream.")

  command(:whoslive, :show_live_users)
    .feature(:twitch).no_args.pm_enabled(false).usage('whoslive')
    .description('Lists which users in this server are live.')

  command(:twitch, :link_twitch)
    .feature(:twitch).args_range(1, 1).usage('twitch <twitch_name>')
    .description('Links the given Twitch stream.')

  command(:managestreams, :manage_streams)
    .feature(:twitch).args_range(0, 2).pm_enabled(false)
    .permissions(:manage_server).usage('managestreams [option] [argument]')
    .description('Used to manage stream announcements. Try the "help" option for more details.')

  event(:playing, :on_playing_status_change)

  def redis_name
    :twitch
  end

  def config_name
    :twitch
  end

  def live(event)
    user = event.author
    return "Doesn't look like you're live... Make sure you've linked your Twitch account to Discord." unless streaming?(user)

    get_stream_data(stream_username(user))&.format_message
  end

  def show_live_users(event)
    live_users_list = live_users(event.server)
    return 'No one is live at the moment.' if live_users_list.empty?

    preamble_str = "There are currently #{live_users_list.length} users live"
    preamble_str = 'There is currently 1 user live' if live_users_list.length == 1

    preamble_str + "\n" +
      live_users_list.map { |user| "#{user.display_name}: <#{stream_url(user)}>" }
                     .join("\n")
  end

  def link_twitch(event, twitch_name)
    handle_errors(event) do
      event.channel.start_typing
      stream_data = get_stream_data(twitch_name)
      return "There is no channel called #{twitch_name}" if stream_data.nil?

      stream_data.format_message
    end
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

    if event.type.zero?
      user_stream_store.clear_stream_title
      return
    end

    return if stream_url(event.user).nil?

    is_reannounce = user_stream_store.title_cached?
    stream_data = handle_playing_status_change(event)
    return if stream_data.nil?

    @bot.servers.values.each do |server|
      current_redis = server_redis(server)

      next if event.user.on(server).nil?
      next unless Omnic.features[:twitch].enabled?(current_redis)

      post_announcement(event.user, current_redis, stream_data, is_reannounce)
    end
  end

  private

  def twitch_client
    @twitch_client ||= init_twitch_client
  end

  def announce_store
    @announce_store ||= AnnounceStore.new(server_redis)
  end

  def user_stream_store
    @user_stream_store ||= UserStreamStore.new(user_redis)
  end

  def init_twitch_client
    # NOTE: We are assuming work will be finished before the token expires
    bearer_token = TwitchApiClient.new(log: log, auth_url: config.auth_url)
                                  .get_bearer_token(client_id: config.client_id,
                                                    client_secret: config.client_secret)

    Twitch::Client.new(client_id: config.client_id, access_token: bearer_token)
  end

  def streaming?(user)
    !user.activities.streaming.empty?
  end

  def live_users(server)
    server.online_members(include_idle: false, include_bots: false)
          .select { |user| streaming?(user) }
  end

  def announce_channel(announcements = announce_store)
    bot.channel(announcements.channel, @server)
  end

  def stream_url(user)
    user.activities.streaming.first&.url
  end

  def stream_title(user)
    user.activities.streaming.first&.name
  end

  def stream_username(user)
    stream_url(user)&.split('/')&.last
  end

  def manage_stream_user(user, action)
    found_user = find_user(user)
    return found_user.error if found_user.failure?

    if action == :add
      announce_store.add_user(found_user.value)
      "Stream announcements are now enabled for #{found_user.value.display_name}"
    elsif action == :remove
      announce_store.remove_user(found_user.value)
      "Stream announcements are now disabled for #{found_user.value.display_name}"
    end
  end

  def handle_playing_status_change(event)
    return nil if user_stream_store.cached_title == stream_title(event.user)
    return nil if stream_url(event.user).nil?

    count = 0
    stream_data = loop do
      begin
        return if count == 5

        count += 1
        stream_data = get_stream_data(stream_username(event.user))
        break stream_data if stream_data&.live?

        log.debug("Twitch doesn't think the stream is live yet, sleeping for a bit then retrying.")
        sleep(30)
      rescue StandardError => e
        log.error(e.full_message)
        log.debug("Event Type: #{event.type}; User: #{event.user.distinct}; Game: #{stream_title(event.user)}; Stream Username: #{stream_url(event.user)}")
      end
    end

    return nil if user_stream_store.cached_title == stream_data.title

    user_stream_store.cache_stream_title(stream_title(event.user))
    stream_data
  end

  def post_announcement(user, current_redis, stream_data, is_reannounce)
    announcements = AnnounceStore.new(current_redis)
    return unless announcements.enabled?
    return unless announcements.enabled_for_user?(user)

    preamble = announce_preamble(announcements, is_reannounce)
    message = stream_data.format_message(preamble)
    announce_channel(announcements).send_message(message)
  end

  def announce_preamble(announcements_store, is_reannounce = false)
    level = announcements_store.announce_level
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

  def get_stream_data(channel_name)
    log.debug("Retrieving stream data for: #{channel_name}")
    stream_data = get_basic_stream_data(channel_name)
    return nil if stream_data.nil?

    get_full_stream_data(stream_data)

    log.debug("  #{stream_data}")
    stream_data
  end

  def get_basic_stream_data(channel_name)
    return nil if channel_name.nil?

    user_result = twitch_client.get_users(login: channel_name)
    return nil if user_result.data.empty?

    Stream.new(user_result.data.first)
  end

  def get_full_stream_data(stream_data)
    streams_result = twitch_client.get_streams(user_login: stream_data.login)
    stream_data.populate(streams_result.data)
    return unless stream_data.playing_game?

    stream_data.game = get_twitch_game(stream_data.game_id)
  end

  def get_twitch_game(game_id)
    twitch_client.get_games(id: game_id).data.first.name
  end

  def manage_streams_summary
    return 'Stream announcements are disabled, set an announcement channel to enable' unless announce_store.enabled?

    response = "Stream announcement channel: #{announce_channel.mention}"
    response += "\nAnnouncement level: #{announce_store.announce_level}"

    users = announce_store.users.map { |id| @server.member(id).display_name }
    response + "\nUsers: #{users.join(', ')}"
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

    announce_store.announce_level = level
    message
  end

  def update_stream_announce_channel(channel)
    found_channel = find_channel(channel)
    return found_channel.error if found_channel.failure?

    announce_store.channel = found_channel.value

    "Stream announcement channel has been set to #{found_channel.value.mention}"
  end

  def disable_stream_announcements
    announce_store.clear_channel
    'Stream announcements have been disabled.'
  end
end
