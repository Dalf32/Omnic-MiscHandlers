# blizz_track_client.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/api_client'
require_relative 'blizz_track_versions_response'
require_relative 'blizz_track_patch_notes_response'

class BlizzTrackClient < ApiClient
  def initialize(log:, base_url:, versions_pattern:, notes_pattern:)
    super(log: log)

    @versions_url = base_url + versions_pattern
    @notes_url = base_url + notes_pattern
  end

  def get_patch_version(realm)
    request_url = format(@versions_url, realm)
    response_hash = make_get_request(request_url)
    BlizzTrackVersionsResponse.new(response_hash)
  end

  def get_patch_notes(realm)
    request_url = format(@notes_url, realm)
    response_hash = make_get_request(request_url)
    BlizzTrackPatchNotesResponse.new(response_hash)
  end
end
