# weather_handler.rb
#
# Author::  Kyle Mullins

require 'forecast_io'

class WeatherHandler < CommandHandler
  feature :weather, default_enabled: true

  command(:locations, :locations)
    .feature(:weather).no_args.usage('locations')
    .description('Lists all registered weather locations.')

  command(:addlocation, :add_location)
    .feature(:weather).args_range(3, 3)
    .usage('addlocation <name> <latitude> <longitude>')
    .description('Registers a new weather location with the given latitude and longitude.')

  command(:dellocation, :remove_location)
    .feature(:weather).args_range(1, 1).usage('dellocation <name>')
    .description('Removes the registered weather location of the given name.')

  command(:weather, :show_weather)
    .min_args(0).feature(:weather).limit(delay: 120, action: :on_limit)
    .usage('weather [*locations]')
    .description('Shows weather data for the given location or for all registered locations if none was specified.')

  def config_name
    :weather
  end

  def redis_name
    :weather
  end

  def locations(_event)
    locations = get_locations

    return 'There are no locations registered yet.' if locations.empty?
    "Registered locations: #{locations.join(', ')}"
  end

  def add_location(_event, name, latitude, longitude)
    return "#{name} is already registered!" if get_locations.include?(name)

    server_redis.hmset("location:#{name}", :latitude, latitude, :longitude, longitude)

    "Location #{name} (#{latitude}, #{longitude}) was registered."
  end

  def remove_location(_event, name)
    return "#{name} is not registered!" unless get_locations.include?(name)

    server_redis.del("location:#{name}")

    "Location #{name} was removed."
  end

  def show_weather(event, *locations)
    return show_all_weather(event) if locations.empty?

    registered_locs = get_locations

    unless (registered_locs & locations) == locations
      return (locations - registered_locs).map { |loc| "#{loc} is not a registered location." }.join("\n")
    end

    locations.each do |location|
      send_weather_embed(event.channel, location)
    end

    nil
  end

  def show_all_weather(event)
    locations = get_locations

    return 'There are no locations registered yet.' if locations.empty?

    locations.each do |loc|
      send_weather_embed(event.channel, loc)
    end

    nil
  end

  def on_limit(event, time_remaining)
    time_remaining = time_remaining.ceil
    message = "Slow down there, buddy. Wait #{time_remaining} more second#{time_remaining == 1 ? '' : 's'} before you try again."
    bot.send_temporary_message(event.message.channel.id, message, time_remaining + 2)

    nil
  end

  def initialize(*args)
    super

    ForecastIO.configure do |forecast_conf|
      forecast_conf.api_key = config.api_key
    end
  end

  private

  def send_weather_embed(channel, location)
    coordinates = get_coordinates(location)
    weather = ForecastIO.forecast(*coordinates)

    channel.send_embed(' ') do |embed|
      embed.title = "Weather for #{location}"
      fill_weather_embed(weather, embed)
    end
  end

  def get_locations
    loc_prefix = 'location:'
    server_redis.keys(loc_prefix + '*').map { |loc_key| loc_key.gsub(loc_prefix, '') }
  end

  def get_coordinates(location)
    loc_key = "location:#{location}"
    [server_redis.hget(loc_key, :latitude), server_redis.hget(loc_key, :longitude)]
  end

  def fill_weather_embed(weather, embed)
    current = weather.currently
    today = weather.daily.data.find { |d| Time.at(d.time).day == Time.now.day }

    embed.url = "https://darksky.net/forecast/#{weather.latitude},#{weather.longitude}"

    storm_str = current.nearestStormDistance.zero? ? 'There is a storm nearby!' :
        "There is a storm #{current.nearestStormDistance}mi to the #{cardinal_direction(current.nearestStormBearing)}"

    embed.add_field(name: 'Now', value: <<~NOW
      It is currently #{current.temperature}°F and #{current.summary}.
      Wind: #{current.windSpeed}mph #{cardinal_direction(current.windBearing)}, Humidity: #{(current.humidity * 100).truncate}%, Feels like #{current.apparentTemperature}°F
      #{storm_str if (0..config.near_storm_threshold).cover?(current.nearestStormDistance)}
    NOW
    )

    precip_str = "#{(today.precipProbability * 100).truncate}% chance of #{today.precipType}"

    embed.add_field(name: 'Today', value: <<~TODAY
      High: #{today.temperatureMax}°F, Low: #{today.temperatureMin}°F
      #{precip_str if today.precipProbability.positive?}
    TODAY
    )

    embed.thumbnail = { url: icon_thumbnail(current.icon) }
    embed.timestamp = Time.now
    embed.color = icon_color(current.icon)
    embed.footer = { text: 'Powered by Dark Sky' }
  end

  def icon_color(icon_text)
    config.icon_colors.fetch(icon_text, config.icon_colors.default)
  end

  def icon_thumbnail(icon_text)
    config.icon_thumbs.fetch(icon_text, config.icon_thumbs.default)
  end

  def cardinal_direction(bearing)
    directions = %w[NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW N]
    increment = 22.5
    cur_bearing = 11.25

    directions.each do |direction|
      return direction if (cur_bearing..(cur_bearing + increment)).cover?(bearing)

      cur_bearing += increment
    end

    directions.last
  end
end
