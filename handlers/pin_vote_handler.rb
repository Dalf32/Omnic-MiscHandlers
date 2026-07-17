# pin_vote_handler.rb
#
# AUTHOR:: Kyle Mullins

require_relative 'pin_vote/pin_vote_store'

class PinVoteHandler < CommandHandler
  feature :pinvote, default_enabled: false,
          description: 'Pins messages that receive enough :pushpin: reacts.'

  command(:pinthreshold, :pin_threshold)
    .feature(:pinvote).args_range(0, 1).pm_enabled(false)
    .permissions(:manage_messages).usage('pinthreshold [threshold]')
    .description('Shows or sets the number of :pushpin: reacts needed to pin a message.')

  event(:reaction_add, :on_reaction_change).feature(:pinvote).pm_enabled(false)
  event(:reaction_remove, :on_reaction_change).feature(:pinvote).pm_enabled(false)
  event(:reaction_remove_all, :on_all_reactions_removed).feature(:pinvote).pm_enabled(false)

  event(:message_delete, :on_message_delete).feature(:pinvote).pm_enabled(false)

  def redis_name
    :pinvote
  end

  def pin_threshold(_event, *new_threshold)
    return "Pin threshold: #{pin_store.threshold}" if new_threshold.empty?

    new_threshold = new_threshold.first.to_i
    return 'Invalid threshold.' if new_threshold <= 0

    pin_store.threshold = new_threshold
    "Pin threshold set to #{new_threshold}"
  end

  def on_reaction_change(event)
    message = event.message
    return if message.pinned? && !pin_store.vote_pinned?(message.id) # Not managed

    lock_message(message.id) do
      if message.reacted_with(PIN_EMOJI).count >= pin_store.threshold
        pin_store.pin(message.id)
        message.pin('Vote pinned')
      elsif pin_store.vote_pinned?(message.id)
        pin_store.unpin(message.id)
        message.unpin('Vote unpinned')
      end
    end
  rescue Discordrb::Errors::NoPermission
    audit_warning('Pin Vote', "Bot lacks the permissions necessary to pin/unpin messages.")
    log.warn("Bot lacks the permissions necessary to pin/unpin messages in server: #{format_obj(server)}")
  end

  def on_all_reactions_removed(event)
    message = event.message
    return unless message.pinned?
    return unless pin_store.vote_pinned?(message.id)

    lock_message(message.id) do
      pin_store.unpin(message.id)
      message.unpin('Vote unpinned')
    end
  rescue Discordrb::Errors::NoPermission
    audit_warning('Pin Vote', "Bot lacks the permissions necessary to pin/unpin messages.")
    log.warn("Bot lacks the permissions necessary to pin/unpin messages in server: #{format_obj(server)}")
  end

  def on_message_delete(event)
    message = event.message
    pin_store.unpin(message.id) if pin_store.vote_pinned?(message.id)
  end

  private

  PIN_EMOJI = "\u{1F4CC}" unless defined? PIN_EMOJI

  def pin_store
    @pin_store ||= PinVoteStore.new(server_redis)
  end

  def lock_message(message_id)
    retval = nil

    Omnic.mutex("pin_vote:#{message_id}").tap do |mutex|
      mutex.acquire
      retval = yield
    ensure
      mutex.release
    end

    retval
  end
end
