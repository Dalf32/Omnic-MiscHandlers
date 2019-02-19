# api_maps_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/ow_map'

class ApiMapsResponse < HttpResponse
  def maps
    body.map do |map|
      OwMap.new(id: map[:id], name: map.dig(:name, :en_US)).tap do |owl_map|
        owl_map.basic_info(icon: map[:icon], thumbnail: map[:thumbnail],
                           type: map[:type])
      end
    end
  end
end
