# frozen_string_literal: true

require 'chronic_duration'
require_relative 'naming_registrar'
require_relative 'data/horse'
require_relative 'data/race_bet'
require_relative 'data_storage/horse_data_store'
require_relative 'data_storage/news_data_store'
require_relative 'data_storage/race_data_store'
require_relative 'output/race_processor'
require_relative 'output/basic_announcer'
require_relative 'output/injury_announcer'
require_relative 'output/podium_announcer'
require_relative 'output/standings_sorter'
require_relative 'output/standings_clusterer'

class HorseracingPlugin < HandlerPlugin
  include GamblingHelper

  def self.plugin_target
    GamblingHandler
  end

  feature :horseracing, default_enabled: false,
          description: 'Allows betting on simulated horse races'

  command(:raceday, :show_race_schedule)
    .feature(:horseracing).no_args.usage('raceday')
    .description('Shows races coming up in the next 24 hours that can be bet on.')

  command(:racecard, :show_race_info)
    .feature(:horseracing).min_args(1).usage('racecard <race name/number>')
    .description('Shows detailed information about an upcoming race.')

  command(:watchrace, :watch_race)
    .feature(:horseracing).min_args(1).usage('watchrace <race name/number>')
    .pm_enabled(false)
    .description('Ensures that the given race run is output in this channel, even if there are no bets.')

  command(:racebet, :bet_on_race)
    .feature(:horseracing).min_args(1).usage('racebet <race name/number>')
    .pm_enabled(false)
    .description('Enters a bet on the given race and ensures that race run is output in this channel.')

  command(:racehelp, :show_help)
    .feature(:horseracing).no_args.usage('racebethelp')
    .description('Displays an explainer on how horse racing works.')

  command(:horseinfo, :show_horse_info)
    .feature(:horseracing).usage('horseinfo [horse name]')
    .description('Lists all currently active race horses or shows more detailed information about the given race horse.')

  command(:racingnews, :show_race_news)
    .feature(:horseracing).no_args.usage('racingnews')
    .description('Shows horse racing events from the last 24 hours that you may have missed.')

  event(:ready, :init_horseracing)

  def init_horseracing(_event)
    load((content_folder + 'horseracing_rules.rb').to_s) unless defined? HorseracingRules
    load_naming_data
    thread(:horseracing_thread, &method(:run_races))
  end

  def show_race_schedule(event)
    event.channel.start_typing

    upcoming_races = race_data_store.schedule.upcoming_races
    return 'No races scheduled.' if upcoming_races.empty?

    races_with_time = upcoming_races.map { |race| format_race_for_sched(race, event) }
    "Upcoming races:\n#{races_with_time.map.with_index { |race_str, index| "#{index + 1}. #{race_str}" }.join("\n")}"
  end

  def show_race_info(event, *race_name_num)
    event.channel.start_typing

    found_race, _race_index = find_upcoming_race(race_name_num)
    return 'No matching race on the schedule' if found_race.nil?

    "```#{found_race}```"
  end

  def watch_race(event, *race_name_num)
    event.channel.start_typing

    found_race, race_index = find_upcoming_race(race_name_num)
    return 'No matching race on the schedule' if found_race.nil?

    watch = WatchBet.create(server: event.message.server.id,
                            channel: event.message.channel.id)
    found_race << watch
    race_data_store.save_scheduled_race(race_index, found_race)

    "OK, the #{found_race.name} will be announced here <t:#{found_race.time}:R>"
  end

  def bet_on_race(event, *race_name_num)
    ensure_funds(event.message)
    event.channel.start_typing

    found_race, race_index = find_upcoming_race(race_name_num)
    return 'No matching race on the schedule' if found_race.nil?

    # prompt for horse
    event.message.reply('Which horse would you like to bet on?')
    horse_name = event.message.author.await!(timeout: 30)&.text
    found_horse = found_race.horses.find { |horse| horse.name.casecmp?(horse_name) }
    return 'Bet cancelled.' if horse_name.nil? || horse_name.empty?
    return 'No horse by that name is running in this race.' if found_horse.nil?

    # prompt for bet
    event.message.reply('What is your wager?')
    wager = event.message.author.await!(timeout: 30)&.text
    return 'Bet cancelled.' if wager.nil? || wager.empty?

    bet_type, wager = wager.downcase.split(' ', 2)

    lock_funds(event.message.author.id) do
      wager_result = wager_for_gambling(wager)
      wager_amt = wager_result.value
      return wager_result.error if wager_result.failure?

      bet = case bet_type.downcase
        when 'win'
          WinBet.create(server: event.message.server.id,
                        channel: event.message.channel.id,
                        user: event.message.author.id,
                        horse: found_horse.name, wager: wager_amt)
        when 'show'
          ShowBet.create(server: event.message.server.id,
                         channel: event.message.channel.id,
                         user: event.message.author.id,
                         horse: found_horse.name, wager: wager_amt)
        when 'place'
          PlaceBet.create(server: event.message.server.id,
                          channel: event.message.channel.id,
                          user: event.message.author.id,
                          horse: found_horse.name, wager: wager_amt)
        else
          return 'Invalid type of bet'
      end

      found_race << bet
      race_data_store.save_scheduled_race(race_index, found_race)
      funds_set[event.message.author.id] -= wager_amt

      "#{bet} entered for the #{found_race.name}"
    end
  end

  def show_help(_event)
    <<~HELP
      Races are scheduled to run on the hour and will be run silently by default. Entering a Bet or using the watchrace command will output that Race to the current channel.
      You can see upcoming Races with the raceday command, and view the details of a single Race using the racecard command.
      Bets are entered with the racebet command. You enter Bets one Horse at a time with the format <bet type> <wager amount>.

      Three types of Bets can be made:
        Win - The Horse must place first; max payout
        Show - The Horse must place first or second; moderate payout
        Place - The Horse must place first, second, or third; minimum payout

      Horses are displayed with their stat rankings (S-F) in parenthesis, in the following order Speed-Power-Stamina. Their record is listed after as Races won/Races run, followed by their average placement (APl). Additional information on Horses can be shown with the horseinfo command.

      The results of recent Races as well as other significant events in the past 24 hours can be seen with the racingnews command.
    HELP
  end

  def show_horse_info(event, *horse_name)
    if horse_name.empty?
      event.channel.start_typing

      active_horses = horse_data_store.active_horses
                                      .sort_by { |horse| [horse.record.races_run * -1, horse.name] }
      return "Active Horses (#{active_horses.count} total):\n  #{active_horses.join("\n  ")}"
    end

    horse_name = horse_name.join(' ')
    return 'There is no record of a race horse by that name.' unless horse_data_store.exists?(horse_name)

    horse_data_store.horse(horse_name).to_s_detail
  end

  def show_race_news(_event)
    news_data_store.get_news.to_a.sort_by(&:first).map do |time, news_items|
      "<t:#{time}:t>\n  #{news_items.join("\n  ")}"
    end.join("\n")
  end

  private

  def content_folder
    Pathname.new(config.horseracing.content_folder)
  end

  def naming_registrar
    NamingRegistrar.instance
  end

  def load_naming_data
    yaml_opts = { permitted_classes: [Symbol, Range], symbolize_names: true, freeze: true }
    horse_name_data = YAML.load_file(content_folder + 'horse_names.yml', **yaml_opts)
    race_name_data = YAML.load_file(content_folder + 'race_names.yml', **yaml_opts)

    naming_registrar.logger = log
    naming_registrar.load(horse_name_data, race_name_data)
  end

  def horse_data_store
    @horse_data_store ||= HorseDataStore.new(global_redis)
  end

  def race_data_store
    @race_data_store ||= RaceDataStore.new(global_redis, horse_data_store)
  end

  def news_data_store
    @news_data_store ||= NewsDataStore.new(global_redis)
  end

  def find_upcoming_race(race_name_num)
    race_name = race_name_num.join(' ')
    race_num = race_name.to_i
    upcoming_races = race_data_store.schedule.upcoming_races

    if race_num.zero?
      found_race = upcoming_races.find { |race| race.name.casecmp?(race_name) }
      similar_races = upcoming_races.select { |race| race.name.downcase.start_with?(race_name.downcase) }
      found_race = similar_races.first if found_race.nil? && similar_races.count == 1
    else
      found_race = upcoming_races[race_num - 1]
    end
    return nil if found_race.nil?

    [found_race, race_num.zero? ? upcoming_races.index(found_race) : race_num - 1]
  end

  def format_race_for_sched(race, event)
    is_watched = race.bets.any? { |bet| bet.server == event.message.server && bet.channel == event.message.channel }
    "#{race.to_s_short} @<t:#{race.time}:f> #{is_watched ? '\👁' : ''}"
  end

  def run_races
    loop do
      # get active horses
      active_horses = get_and_manage_horses

      # get schedule
      schedule = get_and_manage_schedule(active_horses)

      # sleep until next race
      sleep_til_next_race(schedule.next_race)

      # re-pull next race and remove it from the schedule in storage
      race = race_data_store.pop_next_race

      # run next race
      race_results = race.run(build_announcer(race))

      ## report race to channels as needed
      post_race_results(race, race_results)

      # record results
      record_results(race, race_results)

      # payout bets
      handle_and_post_payouts(race, race_results)

      # remove race from schedule
      schedule.remove_race
    rescue StandardError => err
      log.error(err)
      sleep_thread(360)
    end
  end

  def get_and_manage_horses
    active_horses = horse_data_store.active_horses
    ## retire and breed as needed
    injure_horses(active_horses)
    retired_horses = retire_horses(active_horses)
    active_horses -= retired_horses
    active_horses += breed_retired_horses(retired_horses)
    ## fill horses as needed
    active_horses + breed_new_horses(active_horses.size)
  end

  def injure_horses(active_horses)
    return unless rand < HorseracingRules.injury_chance

    injury = HorseracingRules.injury_map.sample
    injured_horse = active_horses.sample
    injured_horse.injure(injury.first)
    horse_data_store.save_horse(injured_horse)
    news_data_store << "#{injured_horse.name} suffered a #{injury.last} injury during training."
  end

  def retire_horses(active_horses)
    active_horses.select(&:retired?).tap do |retired_horses|
      retired_horses.each do |retired_horse|
        horse_data_store.remove_active_horse(retired_horse)
        news_data_store << "#{retired_horse.name} retired after competing in #{retired_horse.record.races_run} races."
      end
    end
  end

  def breed_retired_horses(retired_horses)
    retired_horses.select(&:should_breed?).each do |retired_horse|
      rand(HorseracingRules.offspring_range).times do
        horse_name = naming_registrar.generate_valid_horse_name(horse_data_store)
        retired_horse.breed(horse_name).tap do |horse|
          horse_data_store.save_horse(horse)
          horse_data_store.add_active_horse(horse)
          news_data_store << "#{horse.name}, bred from #{retired_horse.name}, is ready to race!"
        end
      end
    end
  end

  def breed_new_horses(num_active_horses)
    [HorseracingRules.min_active_horses - num_active_horses, 0].max.times.to_a.map do
      horse_name = naming_registrar.generate_valid_horse_name(horse_data_store)
      Horse.breed(horse_name).tap do |horse|
        horse_data_store.save_horse(horse)
        horse_data_store.add_active_horse(horse)
        news_data_store << "#{horse.name} was registered and is ready to race!"
      end
    end
  end

  def get_and_manage_schedule(active_horses)
    race_data_store.schedule.tap do |schedule|
      ## fill schedule if needed
      new_races = schedule.fill(active_horses, naming_registrar)
      save_new_races(new_races)
      race_data_store.championship_counter = schedule.championship_counter
    end
  end

  def save_new_races(new_races)
    new_races.each do |new_race|
      race_data_store.save_race(new_race.race)
      horse_data_store.save_race_horses(new_race.id, new_race.entrants)
      race_data_store.push_race(new_race)
    end
  end

  def build_announcer(race)
    return SilentAnnouncer.new if race.bets.empty?

    StandingsSorter.new
                   .then(StandingsClusterer.new)
                   .then(BasicAnnouncer.new)
                   .then(InjuryAnnouncer.new)
                   .then(PodiumAnnouncer.new)
  end

  def post_race_results(race, race_results)
    return unless race.bets?

    race_preamble = "The horses are going down to the gates, ready to start the **#{race.to_s_short}**..."
    post_to_race_channels(race, race_preamble, start_typing: true)
    sleep_thread(config.horseracing.leg_delay)

    post_to_race_channels(race, "And they're off!", start_typing: true)

    race_results.casts.each do |leg_casts|
      sleep_thread(config.horseracing.leg_delay)
      post_to_race_channels(race, leg_casts.join("\n"), start_typing: true)
    end
  end

  def post_to_race_channels(race, message_text, start_typing: false)
    return unless race.bets?

    race.bets.group_by { |bet| "#{bet.server}.#{bet.channel}" }.each do |_, bets|
      server = Omnic.bot.server(bets.first.server)
      next if server.nil?

      channel = Omnic.bot.channel(bets.first.channel, server)
      next if channel.nil?

      channel.send_message(message_text)
      channel.start_typing if start_typing
    end
  end

  def record_results(race, race_results)
    race.record_results(race_results)
    race_data_store.save_race(race.race)
    horse_data_store.save_horses(race.horses)
    news_data_store << "#{race_results.winner.name} won the #{race.to_s_short}"

    race_results.injuries.each do |injured_horse|
      news_data_store << "#{injured_horse.name} suffered a #{injured_horse.injury} injury during the #{race.to_s_short}"
    end
  end

  def handle_and_post_payouts(race, race_results)
    return unless race.bets?

    filtered_bets = race.bets.filter { |bet| bet.win?(race_results) }
    filtered_bets.group_by { |bet| "#{bet.server}.#{bet.channel}" }.each do |_, bets|
      server = Omnic.bot.server(bets.first.server)
      next if server.nil?

      channel = Omnic.bot.channel(bets.first.channel, server)
      next if channel.nil?

      payout_text = bets.map do |bet|
        user = server.member(bet.user)
        next if user.nil?

        horse = race.entrants.find { |horse| horse.name == bet.horse }
        payout = bet.payout(horse.odds_float)
        lock_funds(user.id, server.id) { funds_set(server_redis(server))[user.id] += payout }

        "#{user.mention} won #{payout.format_currency} from a #{bet}"
      end.compact.join("\n")

      next if payout_text.empty?
      channel.send_message(payout_text)
    end
  end

  def sleep_til_next_race(next_race)
    race_warning = config.horseracing.race_warning || 0
    sleep_time = next_race.time - Time.now.to_i - race_warning
    sleep_thread(sleep_time)

    # warn race is about to start unless it is set to 0
    unless race_warning.zero? || sleep_time <= 0
      post_to_race_channels(next_race, "The #{next_race.to_s_short} is starting soon!")
      sleep_thread(race_warning)
    end
  end

  def sleep_thread(duration)
    return if duration <= 0

    log.debug("Sleeping Horseracing thread for #{duration}s")
    sleep(duration)
  end
end
