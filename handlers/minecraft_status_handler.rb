# minecraft_status_handler.rb
#
# Author::  Kyle Mullins

require_relative 'minecraft/minecraft_status_client'

class MinecraftStatusHandler < CommandHandler
  feature :minecraft, default_enabled: true

  command(:mcserver, :show_url)
    .feature(:minecraft).no_args.usage('mcserver')
    .description('Posts the address of the Minecraft server.')

  command(:mcstatus, :show_status)
    .feature(:minecraft).no_args.usage('mcstatus')
    .description('Shows the current status of the Minecraft server.')

  def config_name
    :minecraft_status
  end

  def show_url(_event)
    config.server_url
  end

  def show_status(_event)
    status_response = api_client.get_server_status(config.server_url)

    return 'An unexpected error occurred.' if status_response.error?
    return 'There was a problem contacting the server.' if status_response.ping_error?
    return 'The Minecraft server is offline.' unless status_response.online?

    "The Minecraft server **#{status_response.title}** is online. There are currently #{status_response.current_players} people playing."
  end

  private

  def api_client
    @api_client ||= MinecraftStatusClient.new(log: log, base_url: config.service_base_url,
                                              status_endpoint: config.status_endpoint)
  end
end
