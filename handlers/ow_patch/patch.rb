# patch.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'version_number'
require_relative 'patch_notes'

class Patch
  include Comparable

  attr_reader :title, :version

  def initialize(id:, url:, title:, publish_date:)
    @id = id
    @url = url
    @title = title
    @publish_date = publish_date
  end

  def version_number(version_str)
    @version = VersionNumber.from_str(version_str)
    self
  end

  def notes(notes_html)
    @notes_html = notes_html
    self
  end

  def fill_embed(embed)
    parsed_notes = PatchNotes.new(@notes_html)

    embed.title = @title
    embed.url = @url
    embed.author = { name: parsed_notes.title, url: @url }

    parsed_notes.sections.each do |section|
      embed.add_field(name: section.print_title, value: section.print)
    end
  end

  def <=>(other)
    @version <=> other.version
  end
end
