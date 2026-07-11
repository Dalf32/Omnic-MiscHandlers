# Omnic - Miscellaneous Handlers
Less-broadly applicable Handlers for Omnic.

### Gambling
Tracks fake funds for each user and allows them to gamble it away through a number of games.

Handler: `handlers/gambling_handler.rb`

Plugins:

- `handlers/gambling/duel_plugin.rb`
- `handlers/gambling/slots/slots_plugin.rb`
- `handlers/gambling/blackjack/blackjack_plugin.rb`
- `handlers/gambling/roulette/roulette_plugin.rb`
- `handlers/gambling/horseracing/horseracing_plugin.rb`

Config:
```ruby
config.handlers.gambling do |gambling|
  gambling.start_funds = 1000
  
  gambling.slots.symbols = %w[
    :tangerine: :lemon: :apple: :pineapple:
    :grapes: :strawberry: :seven: :cherries:
    :watermelon: :peach: :banana: :bell:
    :four_leaf_clover: :moneybag: :gem: :credit_card:
  ]
  gambling.slots.paytable = {
    [16, 16, 16] => 300,
    [15, 15, 15] => 200,
    [14, 14, 14] => 100,
    [7, 7, 7] => 75,
    [10, 11, 10] => 69,
    [11, 10, 11] => 69,
    [13, 13, 13] => 42,
    [11, 11, 11] => 35,
    [10, 10, 10] => 25,
    [3, 6, 9] => 1,
    [5, 10, 15] => 0.75,
    [7, 8, 9] => 0.5,
    [1, 2, 3] => 0.25
  }

  gambling.blackjack.ranks = Hash.new { |_, k| k.to_s }
  gambling.blackjack.ranks[1] = 'Ace'
  gambling.blackjack.ranks[11] = 'Jack'
  gambling.blackjack.ranks[12] = 'Queen'
  gambling.blackjack.ranks[13] = 'King'
  gambling.blackjack.suits = Hash.new { |_, k| " of #{k.to_s.capitalize}" }
  gambling.blackjack.num_decks = 4
  
  gambling.horseracing.content_folder = 'handlers/gambling/horseracing/content'
  gambling.horseracing.race_warning = 10 * 60 # 10 mins
  gambling.horseracing.leg_delay = 8
end
```

### GDQ
Hooks into the Games Done Quick API to set the current run as the bot's status and allow checking the schedule from Discord.

Handler: `handlers/gdq_handler.rb`

Config:
```ruby
config.handlers.gdq do |gdq|
  gdq.base_url = 'https://gamesdonequick.com'
  gdq.schedule_url = '/schedule'
  gdq.api_url = '/api/schedule/'
  gdq.stream_url = 'https://www.twitch.tv/gamesdonequick'
  gdq.schedule_radius = 3
  gdq.run_length_decoration = ':stopwatch:'
  gdq.start_time_decoration = ':alarm_clock: '
  gdq.min_sleep_time = 10 * 60 # 10 minutes (in seconds)
  gdq.max_sleep_time = 7 * 24 * 60 * 60 # 1 week (in seconds)
end
```

### RSS
Allows configuring RSS feeds to be checked periodically and updates posted to a channel.

Handler: `handlers/rss_handler.rb`

Config:
```ruby
config.handlers.rss do |rss|
  rss.min_sleep_time = 5 * 60 # 5 minutes (in seconds)
  rss.max_sleep_time = 7 * 24 * 60 * 60 # 1 week (in seconds)
end
```

### Twitch
Enables automatic go-live posts for specific users on the server.

Handler: `handlers/twitch_handler.rb`

Config:
```ruby
config.handlers.twitch do |twitch|
  twitch.auth_url = 'https://id.twitch.tv/oauth2/token?grant_type=client_credentials'
  twitch.client_id = '' # Twitch account client ID
  twitch.client_secret = '' # Twitch account client secret
end
```
