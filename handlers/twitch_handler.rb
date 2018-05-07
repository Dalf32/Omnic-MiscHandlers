# twitch_handler.rb
#
# Author::  Kyle Mullins

class TwitchHandler < CommandHandler
  feature :twitch, default_enabled: true

  command :live, :live, feature: :twitch, max_args: 0, usage: 'live',
      description: "Announces that you're live and links your stream."

  command :whoslive, :show_live_users, feature: :twitch, max_args: 0,
      usage: 'whoslive', description: 'Lists which users in this server are live.'

  command :twitch, :link_twitch, feature: :twitch, min_args: 1, max_args: 1,
      usage: 'twitch <twitch_name>', description: 'Links the given Twitch stream.'

  command :streamannchannel, :set_stream_announce_channel, feature: :twitch,
      max_args: 1, usage: 'streamannchannel [channel_name]',
      description: 'Sets or clears the channel for stream announcements.'

  command :addstreamuser, :add_stream_user, feature: :twitch, min_args: 1,
      max_args: 1, required_permissions: [:administrator],
      usage: 'addstreamuser <user>',
      description: 'Enables stream announcements for the given user.'

  command :remstreamuser, :remove_stream_user, feature: :twitch, min_args: 1,
      max_args: 1, required_permissions: [:administrator],
      usage: 'remstreamuser <user>',
      description: 'Disables stream announcements for the given user.'

  command :streamusers, :list_stream_users, feature: :twitch, max_args: 0,
      usage: 'streamusers',
      description: 'Lists all members with stream announcements enabled.'

  event :playing, :on_playing_status_change, feature: :twitch

  def redis_name
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
    "https://www.twitch.tv/#{twitch_name}"
  end

  def set_stream_announce_channel(event, *channel)
    if channel.empty?
      server_redis.del(:announce_channel)
      return 'Stream announcement channel has been cleared.'
    end

    channels = bot.find_channel(channel.first, event.server.name, type: 0)

    return "#{channel} does not match any channels on this server" if channels.empty?
    return "#{channel} matches more than one channel on this server" if channels.count > 1

    server_redis.set(:announce_channel, channels.first.id)

    "Stream announcement channel has been set to ##{channels.first.name}"
  end

  def add_stream_user(_event, user)
    manage_stream_user(user, :add)
  end

  def remove_stream_user(_event, user)
    manage_stream_user(user, :remove)
  end

  def list_stream_users(_event)
    users = server_redis.smembers(:announce_users).map { |id| @server.member(id) }

    return 'Stream announcements are not enabled for any users' if users.empty?

    "Stream announcements are enabled for the following users: #{users.map(&:display_name).join(', ')}"
  end

  def on_playing_status_change(event)
    return unless announcements_enabled?
    return unless announce_enabled_for_user?(event.user)

    unless event.type == 1
      server_redis.del(cache_key(event.user.id))
      return
    end

    return if get_cached_title(event.user) == event.user.game

    member = event.server.member(event.user.id)
    announce_channel.send_message(stream_announce_message(member, '@everyone'))
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

  def stream_announce_message(user, preamble = '@here')
    message = "#{preamble} #{user.display_name} is live now! Check them out: #{user.stream_url}"
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
end