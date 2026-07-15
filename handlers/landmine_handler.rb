# LandmindHandler.rb
#
# AUTHOR:: Kyle Mullins

require 'chronic_duration'

class LandmineHandler < CommandHandler
  feature :landmines, default_enabled: false,
          description: 'Places landmines throughout the server which time out any who trip on them.'

  command(:armmines, :arm_landmines)
    .feature(:landmines).args_range(2, 2).pm_enabled(false)
    .permissions(:moderate_members).usage('armmines <density> <damage>')
    .description('Lays out landmines with the given density (% to trigger) and damage (time out seconds).')

  command(:disarmmines, :disarm_landmines)
    .feature(:landmines).no_args.pm_enabled(false)
    .permissions(:moderate_members).usage('disarmmines')
    .description('Disarms the landmines in the server.')

  event(:message, :on_message).feature(:landmines).pm_enabled(false)

  def redis_name
    :landmines
  end

  def arm_landmines(_event, density, damage)
    density = density.to_f
    damage = damage.to_i
    return 'Density must be a positive number.' unless density.positive?
    return 'Damage must be a positive integer.' unless damage.positive?
    return 'Damage cannot exceed 2,419,200.' if damage > 2_419_200

    server_redis.set(DENSITY_KEY, density)
    server_redis.set(DAMAGE_KEY, damage)
    'Watch out! Landmines have been armed!'
  end

  def disarm_landmines(_event)
    server_redis.del(DENSITY_KEY)
    server_redis.del(DAMAGE_KEY)
    'Landmines disarmed.'
  end

  def on_message(event)
    return unless landmines_armed?

    victim = event.message.author
    return if victim.bot_account?

    density, damage = *landmines_config
    return if rand(100) > density

    victim.timeout = Time.now + damage
    event.message.reply("💥**BOOM!**💥 #{victim.mention} stepped on a landmine and exploded!\n*Their wounds will heal in #{ChronicDuration.output(damage)}.*")
  rescue Discordrb::Errors::NoPermission
    log.warn("Bot lacks the permissions necessary to time out user: #{format_obj(victim)} in server: #{format_obj(server)}")
  end

  private

  DENSITY_KEY = :density
  DAMAGE_KEY = :damage

  def landmines_armed?
    server_redis.exists?(DENSITY_KEY) && server_redis.exists?(DAMAGE_KEY)
  end

  def landmines_config
    [server_redis.get(DENSITY_KEY).to_f, server_redis.get(DAMAGE_KEY).to_i]
  end
end
