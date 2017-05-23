# wikia_command.rb
#
# Author::  Kyle Mullins

class WikiaCommand
  attr_reader :wiki_name

  def initialize(command_hash)
    @command = command_hash[:command]
    @display_name = command_hash[:display_name]
    @wiki_name = command_hash[:wiki_name]
    @embed_color = command_hash[:color]
  end

  def has_color?
    !@embed_color.nil?
  end

  def matches?(command_name)
    @command.to_sym == command_name.to_sym
  end

  def fill_embed(embed)
    embed.title = @display_name
    embed.color = @embed_color if has_color?
  end
end