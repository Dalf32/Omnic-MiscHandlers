# wikia_search_handler.rb
#
# Author::  Kyle Mullins

require_relative 'wikia/wikia_api_client'
require_relative 'wikia/wikia_command'

class WikiaSearchHandler < CommandHandler
  feature :wikia, default_enabled: true

  event :ready, :create_commands

  def config_name
    :wikia
  end

  def wikia_search(event, *search_terms)
    wikia_command = wikia_command(event.content.split.first[1..-1])
    query = search_terms.join(' ')
    search_response = api_client.search(wikia_command.wiki_name, query, limit: config.results_limit)

    return 'No results found.' if search_response.no_results?
    return 'An error occurred, unable to retrieve any results.' if search_response.error?

    first_details_response = api_client.get_article_details(wikia_command.wiki_name, search_response.items.first.id)

    return 'An error occurred, unable to retrieve any results.' if first_details_response.error?

    article_details = first_details_response.items.first

    content = "#{event.author.display_name} searched for \"#{query}\""
    event.channel.send_embed(content) do |embed|
      wikia_command.fill_embed(embed)
      embed.url = api_client.wiki_url(wikia_command.wiki_name)
      embed.timestamp = Time.now
      embed.add_field(name: 'See Also', value: search_response.items[1..-1].map(&:url).join("\n"))
      article_details.fill_embed(embed)
    end

    nil
  end

  def create_commands(_event)
    config.commands.each do |command_hash|
      WikiaSearchHandler.command command_hash[:command], :wikia_search, feature: :wikia, min_args: 1,
          description: "Searches the #{command_hash[:display_name]} Wiki and returns the top results."
    end
  end

  private

  def api_client
    @api_client ||= WikiaApiClient.new(log: log, basepath_pattern: config.basepath_pattern, endpoints: config.endpoints)
  end

  def wikia_command(command_name)
    config.commands.map { |command_hash| WikiaCommand.new(command_hash) }.find{ |command| command.matches?(command_name) }
  end
end