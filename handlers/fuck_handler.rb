# fuck_handler.rb
#
# Author::  Kyle Mullins

require 'open-uri'
require 'cgi'

class FuckYouHandler < CommandHandler
  command(:fuckyou, :say_random_fuck_you)
    .min_args(1).usage('fuckyou <name>')
    .description('Tells the given person "Fuck you" in a random way.')

  def config_name
    :fuck_api
  end

  def say_random_fuck_you(event, *name_words)
    from = event.user.display_name
    name = name_words.join(' ')
    escaped_from = CGI.escape(from)
    escaped_name = CGI.escape(name)
    endpoint = format(config.fuck_you_endpoints.sample,
                      name: escaped_name, from: escaped_from)

    make_api_request(endpoint).gsub(escaped_from, from).gsub(escaped_name, name)
  end

  private

  def make_api_request(api_endpoint)
    request_url = config.base_url + api_endpoint
    log.debug('Making API GET request: ' + request_url)

    open(request_url, 'accept' => 'text/plain').readlines.join
  end
end
