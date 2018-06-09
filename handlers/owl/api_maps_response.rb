# api_maps_response.rb
#
# AUTHOR::  Kyle Mullins

require_relative '../../api/http_response'
require_relative 'model/owl_map'

class ApiMapsResponse < HttpResponse
  def maps
    body.map do |map|
      OwlMap.new(id: map[:id], name: map.dig(:name, :en_US)).tap do |owl_map|
        owl_map.basic_info(background: map[:background], icon: map[:icon],
                           thumbnail: map[:thumbnail], type: map[:type])
      end
    end
  end
end
