# blizz_track_patch_notes_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'patch'

class BlizzTrackPatchNotesResponse < HttpResponse
  def title
    body[:title]
  end

  def patches
    body[:items]&.map do |item|
      Patch.new(id: item[:id], url: item[:url], title: item[:title],
                publish_date: to_date(item[:date_published]))
           .version_number(item[:id]).notes(item[:content_html])
    end
  end

  private

  def to_date(date)
    DateTime.parse(date) unless date.nil?
  end
end
