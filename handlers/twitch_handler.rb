# twitch_handler.rb
#
# Author::  Kyle Mullins

class TwitchHandler < CommandHandler
  feature :twitch, default_enabled: true

  command :live, :live, feature: :twitch, max_args: 0, usage: 'live',
      description: "Announces that you're live and links your stream."

  command :whoslive, :show_live_users, feature: :twitch, max_args: 0,
      usage: 'whoslive', description: 'Lists which users in this server are live.'

  def live(event)
    user = event.author

    return "Doesn't look like you're live... Make sure you've linked your Twitch account to Discord." unless streaming?(user)

    "@here #{user.display_name} is live now! Check them out: #{user.stream_url}"
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

  private

  def streaming?(user)
    stream_type = user.stream_type.nil? ? 0 : user.stream_type
    stream_type = stream_type.is_a?(String) ? stream_type.to_i : stream_type

    stream_type > 0
  end

  def live_users(server)
    server.online_members(include_idle: false, include_bots: false)
          .select { |user| streaming?(user) }
  end
end