# ow_patch_handler.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'ow_patch/blizz_track_client'

class OwPatchHandler < CommandHandler
  feature :owpatch, default_enabled: true,
                    description: 'Displays Overwatch Patch notes.'

  command(:patches, :show_live_patches)
    .feature(:owpatch).max_args(0).usage('patches')
    .description('Lists the patch versions currently in use on each realm.')

  command(:patchnotes, :show_latest_patch_notes)
    .feature(:owpatch).args_range(0, 2).usage('patchnotes [realm]')
    .description('Shows detailed notes for the latest patch on the given realm (default is Live).')

  command(:patchversion, :show_version_patch_notes)
    .feature(:owpatch).args_range(1, 1).usage('patchversion <version_num>')
    .description('Shows detailed notes for the patch that best matches the given patch version number.')

  command(:searchpatches, :search_patch_notes)
    .feature(:owpatch).min_args(1).usage('searchpatches <search_terms>')
    .description('Searches recent patches for changes related to the given terms.')

  def config_name
    :ow_patch
  end

  def show_live_patches(event)
    handle_errors(event) do
      event.channel.start_typing

      config.realms.map do |name, realm|
        patch_response = patch_notes_client.get_patch_version(realm)
        return 'An unexpected error occurred.' if patch_response.error?

        "#{name}: #{patch_response.patch_version}"
      end.join("\n")
    end
  end

  def show_latest_patch_notes(event, *realm)
    handle_errors(event) do
      event.channel.start_typing

      realm = realm.empty? ? 'live' : realm.join(' ')
      realm_code = config.realms.to_a.find { |(name, _)| matches?(name, realm) }

      return 'No matching realm was found.' if realm_code.nil?

      patch = find_latest_patch(realm_code.last)
      send_patch_notes(event, patch)
    end
  end

  def show_version_patch_notes(event, version_num)
    handle_errors(event) do
      event.channel.start_typing

      return 'Invalid patch version.' unless VersionNumber.valid?(version_num)

      version = VersionNumber.from_str(version_num)
      patch = find_patch_by_version('overwatch', version)
      send_patch_notes(event, patch)
    end
  end

  def search_patch_notes(event, *search_terms)
    'Not yet implemented.'
  end

  private

  def send_patch_notes(event, patch)
    event.channel.send_embed(' ') do |embed|
      patch.fill_embed(embed)
      embed.footer = { text: "Retrieved from #{config.base_url}" }
      embed.timestamp = Time.now
    end
  end

  def patch_notes_client
    @patch_notes_client ||= BlizzTrackClient.new(
      log: log, base_url: config.base_url,
      versions_pattern: config.versions_url_pattern,
      notes_pattern: config.notes_url_pattern
    )
  end

  def matches?(realm_name, input)
    realm_name.to_s.casecmp(input).zero? ||
      realm_name.to_s.downcase.start_with?(input.downcase)
  end

  def find_latest_patch(realm_code)
    patch_notes_response = patch_notes_client.get_patch_notes(realm_code)
    raise 'Unable to retrieve patch notes.' if patch_notes_response.error?

    if patch_notes_response.patches.nil?
      patch_version_response = patch_notes_client.get_patch_version(realm_code)
      raise 'Unable to retrieve patch notes.' if patch_version_response.error?

      version = patch_version_response.patch_version
      return find_patch_by_version('overwatch', version)
    end

    patch_notes_response.patches.first
  end

  def find_patch_by_version(realm_code, version)
    patch_notes_response = patch_notes_client.get_patch_notes(realm_code)
    raise 'Unable to retrieve patch notes.' if patch_notes_response.error?

    patch_notes_response.patches.sort.reverse
                        .min_by { |p| (p.version - version).abs }
  end
end
