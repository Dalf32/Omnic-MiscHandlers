# starboard_handler.rb
#
# AUTHOR::  Kyle Mullins

require 'unicode/emoji'

require_relative 'starboard/starboard_store'

class StarboardHandler < CommandHandler
  feature :starboard, default_enabled: false

  command(:managestarboard, :manage_starboard)
    .feature(:starboard).args_range(0, 2).pm_enabled(false)
    .permissions(:manage_channels).usage('managestarboard [option] [argument]')
    .description('Used to manage starboard options. Try the "help" option for more details.')

  event(:reaction_add, :on_reaction_change).feature(:starboard)
  event(:reaction_remove, :on_reaction_change).feature(:starboard)
  event(:reaction_remove_all, :on_all_reactions_removed).feature(:starboard)

  event(:message_delete, :on_message_delete).feature(:starboard)
  event(:message_edit, :on_message_edit).feature(:starboard)

  def redis_name
    :starboard
  end

  def manage_starboard(_event, *args)
    return manage_starboard_summary if args.empty?

    case args.first
    when 'help'
      manage_starboard_help
    when 'channel'
      return 'Name of Channel is required' if args.size == 1
      update_starboard_channel(args[1])
    when 'threshold'
      return 'Threshold value is required' if args.size == 1
      update_starboard_threshold(args[1])
    when 'emoji'
      return 'Emoji is required' if args.size == 1
      update_starboard_emoji(args[1])
    when 'exclude', 'include'
      return 'Name of Channel is required' if args.size == 1
      manage_excluded_channel(args[1], args.first.to_sym)
    when 'disable'
      starboard.disable
      'Starboard has been disabled.'
    else
      'Invalid option.'
    end
  end

  def on_reaction_change(event)
    return unless starboard.enabled? && starboard_emoji?(event.emoji)
    return self_star_message(event) if self_star_event?(event)

    if starboard.on_board?(event.message.id)
      if starboard_eligible?(event.message)
        edit_starboard_message(event.message)
      else
        remove_from_starboard(event.message.id)
      end
    elsif starboard_eligible?(event.message)
      add_to_starboard(event.message)
    end
  end

  def on_all_reactions_removed(event)
    return unless starboard.enabled?

    msg_id = event.message.id
    remove_from_starboard(msg_id) if starboard.on_board?(msg_id)
  end

  def on_message_delete(event)
    return unless starboard.enabled?
    remove_from_starboard(event.id) if starboard.on_board?(event.id)
  end

  def on_message_edit(event)
    return unless starboard.enabled? && starboard.on_board?(event.message.id)

    edit_starboard_message(event.message)
  end

  private

  EMOJI_MENTION_REGEX = /<(a)?:(\w+):(\d+)>/ unless defined? EMOJI_MENTION_REGEX

  def starboard
    @starboard ||= StarboardStore.new(server_redis)
  end

  def starboard_channel
    @bot.channel(starboard.channel, @server)
  end

  def starboard_emoji
    emoji = starboard.emoji
    return emoji unless EMOJI_MENTION_REGEX =~ emoji

    @bot.parse_mention(emoji)
  end

  def excluded_channels
    starboard.excluded_channels.map { |id| @bot.channel(id, @server) }
  end

  def starboard_eligible?(message)
    !starboard.excluded?(message.channel.id) &&
      count_reactions(message) >= starboard.threshold
  end

  def count_reactions(message)
    (message.reacted_with(starboard_emoji) - [message.author]).count
  end

  def add_to_starboard(message)
    starboard_msg = post_starboard_message(message)
    starboard.add_message(message.id, starboard_msg.id)
  end

  def remove_from_starboard(message_id)
    starboard_msg_id = starboard.message(message_id)
    starboard_channel.delete_message(starboard_msg_id)
    starboard.remove_message(message_id)
  end

  def post_starboard_message(message)
    starboard_channel.send_embed(' ') do |embed|
      populate_starboard_embed(embed, message)
    end
  end

  def edit_starboard_message(message)
    embed = Discordrb::Webhooks::Embed.new
    populate_starboard_embed(embed, message)

    starboard_message = starboard_channel.message(starboard.message(message.id))
    starboard_message.edit(' ', embed)
  end

  def populate_starboard_embed(embed, message)
    embed.title = 'Content'
    embed.description = message.text
    embed.description += "\n<embed>" if message.embeds.any?
    embed.url = "https://discordapp.com/channels/#{@server.id}/#{message.channel.id}/#{message.id}"
    embed.color = member_color(message.author).combined
    # TODO: Replace the above with the below on next Discordrb release
    # embed.color = message.author.color.combined
    embed.timestamp = message.edited_timestamp || message.timestamp
    embed.image = { url: message.attachments.first.url } if message.attachments.any?
    embed.author = { name: message.author.display_name, icon_url: message.author.avatar_url }
    embed.add_field(name: 'Channel', value: message.channel.mention, inline: true)
    embed.add_field(name: starboard.emoji, value: count_reactions(message), inline: true)
  end

  def manage_starboard_summary
    return 'Starboard is disabled, set a Starboard channel to enable' unless starboard.enabled?

    response = "Starboard channel: #{starboard_channel.mention}"
    response += "\nThreshold: #{starboard.threshold}"
    response += "\nEmoji: #{starboard.emoji}"
    response + "\nExcluded channels: #{excluded_channels.map(&:mention).join(', ')}"
  end

  def manage_starboard_help
    <<~HELP
      help - Displays this help text
      channel <channel> - Sets the Channel Starboard posts to
      threshold <threshold> - Sets the minimum reactions needed to make Starboard, default = 5
      emoji <emoji> - Sets the emoji reaction that Starboard looks for, default = ⭐
      exclude <channel> - Excludes the given Channel from Starboard consideration
      include <channel> - Re-includes the given Channel for Starboard consideration
      disable - Disables Starboard
    HELP
  end

  def update_starboard_channel(channel)
    found_channel = find_channel(channel)

    return found_channel.error if found_channel.failure?

    starboard.channel = found_channel.value.id

    "Starboard channel has been set to #{found_channel.value.mention}"
  end

  def update_starboard_threshold(threshold)
    threshold = threshold.to_i
    return 'Threshold value must be an Integer greater than 0' if threshold <= 0

    starboard.threshold = threshold

    "Starboard posts now require #{threshold} reactions at minimum."
  end

  def update_starboard_emoji(emoji)
    return 'Emoji parameter must be either a Unicode or Discord emoji' unless emoji?(emoji)
    return 'Animated emoji are not supported at this time' if emoji.start_with?('<a:') # TODO: Remove this on next Discordrb release

    starboard.emoji = emoji
    "The Starboard emoji is now #{emoji}"
  end

  def manage_excluded_channel(channel, action)
    found_channel = find_channel(channel)

    return found_channel.error if found_channel.failure?

    if action == :exclude
      starboard.exclude_channel(found_channel.value.id)
      "#{found_channel.value.mention} has been excluded from Starboard consideration"
    elsif action == :include
      starboard.include_channel(found_channel.value.id)
      "#{found_channel.value.mention} has been re-included for Starboard consideration"
    end
  end

  def emoji?(emoji_text)
    EMOJI_MENTION_REGEX =~ emoji_text || Unicode::Emoji::REGEX_ANY =~ emoji_text
  end

  def starboard_emoji?(emoji)
    starboard_emoji = starboard.emoji
    emoji.name == starboard_emoji || emoji.mention == starboard_emoji
  end

  def self_star_event?(event)
    event.message.reacted_with(starboard_emoji).include?(event.user) &&
      event.message.author.id == event.user.id
  end

  def member_color(member)
    color_roles = member.roles.select { |r| r.color.combined.nonzero? }
    return nil if color_roles.empty?

    color_roles.sort_by(&:position).last.color
  end

  def self_star_message(event)
    event.channel.send_message("#{event.user.mention}, You cannot #{starboard.emoji} your own messages!")
  end
end
