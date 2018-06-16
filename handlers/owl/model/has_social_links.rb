# has_social_links.rb
#
# AUTHOR::  Kyle Mullins

module HasSocialLinks
  def social(**links)
    @social_links = links
    self
  end

  protected

  def fill_socials_embed(embed)
    return if @social_links.nil? || @social_links.empty?

    slice_size = (@social_links.size / 2.0).ceil
    socials_split = format_socials.each_slice(slice_size).to_a
    has_columns = !socials_split[1].nil?

    embed.add_field(name: 'Social',
                    value: socials_split[0].join("\n"),
                    inline: has_columns)
    embed.add_field(name: '-', value: socials_split[1].join("\n"), inline: true) if has_columns
  end

  def format_socials
    @social_links.map do |type, link|
      "[#{type.to_s.split('_').first.capitalize}](#{link})"
    end
  end
end
