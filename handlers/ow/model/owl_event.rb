# owl_event.rb
#
# AUTHOR::  Kyle Mullins

class OwlEvent
  attr_reader :image

  def initialize(type:, titles:)
    @type = type
    @titles = titles
  end

  def basic_info(loc_text:, loc_url:, descr_url:, image:)
    @location_text = loc_text
    @location_url = loc_url
    @description_url = descr_url
    @image = image
  end

  def embed_str
    "**[#{@titles.join(' ')}](#{@description_url})**\n*[#{@location_text}](#{@location_url})*"
  end
end
