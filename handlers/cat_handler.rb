# cat_handler.rb
#
# Author::	Kyle Mullins

require 'open-uri'
require 'json'

class CatHandler < CommandHandler
  command :cat, :get_random_cat, description: 'Gets a random picture of a cat!'

  def config_name
    :cats
  end

  def get_random_cat(_event)
    cat_url = request_cat['file']

    if cat_url.nil?
      'There was a problem getting your cat :crying_cat_face:'
    else
      cat_url
    end
  end

  private

  def request_cat
    JSON.parse(open(config.uri).string)
  rescue OpenURI::HTTPError, Errno::ECONNREFUSED => http_err
    log.error(http_err)
    {}
  end
end
