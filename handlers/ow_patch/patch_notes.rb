# PatchNotes
#
# AUTHOR::  Kyle Mullins

require 'oga'

class PatchNotes
  attr_reader :title, :sections

  def initialize(patch_html)
    @sections = []
    parse_notes(patch_html)
  end

  private

  def parse_notes(patch_html)
    notes_document = Oga.parse_html(patch_html)
    @title = notes_document.at_xpath('h1').text

    parse_patch_sections(notes_document)
  end

  def parse_patch_sections(notes_document)
    cur_section = nil

    notes_document.each_node do |node|
      next unless node.is_a?(Oga::XML::Element)

      if node.name == 'h2'
        # Section start
        cur_section = PatchSection.new(node.text)
        @sections << cur_section
      elsif node.name == 'p' && !node.at_xpath('u').nil?
        # Section start
        cur_section = PatchSection.new(node.text)
        @sections << cur_section
      elsif node.name == 'p' && !node.at_xpath('strong').nil?
        # Heading
        cur_section&.add_heading(node.text)
      elsif node.name == 'p'
        # Subheading
        cur_section&.add_subheading(node.text)
      elsif node.name == 'ul'
        # Changes
        node.children.find_all { |n| n.is_a?(Oga::XML::Element) }
            .each { |e| cur_section&.add_note(e.text) }
      end

      throw :skip_children
    end
  end
end

class PatchSection
  def initialize(title)
    @title = title
    @elements = []
  end

  def add_heading(heading_text)
    return if heading_text.empty?

    @elements << PatchSectionHeading.new(heading_text)
  end

  def add_subheading(subheading_text)
    return if subheading_text.empty?

    @elements << PatchSectionSubheading.new(subheading_text)
  end

  def add_note(note_text)
    return if note_text.empty?

    @elements << PatchNote.new(note_text)
  end

  def print_title
    "__#{@title}__"
  end

  def print
    @elements.map(&:print).join("\n")
  end
end

class PatchElement
  def initialize(text)
    @text = text
  end
end

class PatchSectionHeading < PatchElement
  def print
    "\n**#{@text}**"
  end
end

class PatchSectionSubheading < PatchElement
  def print
    "*#{@text}*"
  end
end

class PatchNote < PatchElement
  BULLET_POINT = '•'.freeze

  def print
    "#{BULLET_POINT} #{@text}"
  end
end
