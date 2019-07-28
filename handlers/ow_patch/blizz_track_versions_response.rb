# BlizzTrackVersionsResponse
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'version_number'

class BlizzTrackVersionsResponse < HttpResponse
  def patch_version
    VersionNumber.from_str(body.dig(:regions, 0, :versionsname) ||
                               body.dig(:patch_notes, :patchVersion))
  end

  def patch_notes
    body.dig(:patch_notes, :detail)
  end
end
