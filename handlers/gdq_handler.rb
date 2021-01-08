# GdqHandler
#
# AUTHOR::  Kyle Mullins

require 'oga'
require 'open-uri'
require 'tabulo'

require_relative 'gdq/gdq_run'
require_relative 'gdq/gdq_schedule'

class GdqHandler < CommandHandler
  feature :gdq, default_enabled: false,
          description: 'Gets information from the Games Done Quick website.'

  command(:gdq, :link_gdq)
    .feature(:gdq).no_args.pm_enabled(true).usage('gdq')
    .description('Posts a link to the GDQ schedule.')

  command(:gdqnext, :show_next_runs)
    .feature(:gdq).max_args(1).pm_enabled(true).usage('gdqnext [num_runs]')
    .description('Lists the next few runs.')

  command(:gdqprev, :show_prev_runs)
      .feature(:gdq).max_args(1).pm_enabled(true).usage('gdqprev [num_runs]')
      .description('Lists the last few runs.')

  command(:gdqschedule, :show_schedule)
    .feature(:gdq).no_args.pm_enabled(true).usage('gdqschedule')
    .description('Posts a snippet of the GDQ schedule.')

  command(:gdqwhen, :find_run)
    .feature(:gdq).min_args(1).pm_enabled(true).usage('gdqwhen <game>')
    .description('Finds when the given game will be/was run in the current marathon.')

  event :ready, :start_status_thread

  def config_name
    :gdq
  end

  def link_gdq(_event)
    schedule = get_schedule

    if schedule.live?
      "**#{schedule.event_name}** is live now! #{config.stream_url}\n"
    elsif schedule.upcoming?
      event_start = schedule.next.first.time_to_start.to_i
      event_start_str = ChronicDuration.output(event_start,
                                               format: :long, units: 1)
      "**#{schedule.event_name}** starts in #{event_start_str}!\n"
    else
      ''
    end + "<#{config.schedule_url}>"
  end

  def show_next_runs(_event, num_runs = 3)
    return 'Invalid number of runs' unless num_runs.to_i.positive?

    next_runs = get_schedule.next(num_runs.to_i)
    return "Looks like there's no marathon live now." if next_runs.nil?

    next_runs.map { |run| format_run(run) }.join("\n")
  end

  def show_prev_runs(_event, num_runs = 3)
    return 'Invalid number of runs' unless num_runs.to_i.positive?

    prev_runs = get_schedule.previous(num_runs.to_i)
    return "Looks like there's no marathon live now." if prev_runs.nil?

    prev_runs.map { |run| format_run(run) }.join("\n")
  end

  def show_schedule(_event)
    schedule = get_schedule
    radius = config.schedule_radius || 3
    runs = ([schedule.previous(radius)] + [schedule.next(radius)]).flatten.compact

    table = Tabulo::Table.new(runs, border: :modern,
                              row_divider_frequency: 1) do |table|
      table.add_column('Time to Start') { |run| start_time_str(run) }
      table.add_column('Length', &:length_str)
      table.add_column('Run') { |run| run.game_category_str(formatting: false) }
      table.add_column('Runners', &:runners_str)
      table.add_column('Host', &:host) if runs.any?(&:hosted?)
    end

    "__**#{schedule.event_name.upcase}**__```#{table.pack}```"
  end

  def find_run(_event, *game)
    schedule = get_schedule
    return "Looks like there's no marathon live now." unless schedule&.live? || schedule &.upcoming?

    game_name = game.join(' ')
    found_run = schedule.find(game_name)
    return "Couldn't find any matches for #{game_name}." if found_run.nil?

    found_run.to_s_when
  end

  def start_status_thread(_event)
    thread(:gdq_status_thread, &method(:check_gdq_status))
  end

  private

  def get_schedule
    gdq_html = open(config.schedule_url)
    gdq_doc = Oga.parse_html(gdq_html)

    name = gdq_doc.at_xpath("//*[@class='text-gdq-red extra-spacing']")
                  .text.split.first

    run_table = gdq_doc.at_xpath("//*[@id='runTable']")
    runs = run_table.xpath("tbody/tr[@class='second-row' or not(@class)]")
                    .each_slice(2).map do |(row1, row2)|
      GdqRun.from_rows(columns_in_row(row1), columns_in_row(row2))
    end.to_a

    GdqSchedule.new(name, runs)
  end

  def columns_in_row(row)
    row.xpath('td').map(&:text).map(&:strip)
  end

  def format_run(run)
    opts = {
        run_length_deco: config.run_length_decoration,
        start_time_deco: config.start_time_decoration
    }
    run.to_s(**opts.compact)
  end

  def start_time_str(run)
    if run.finished?
      'Finished'
    elsif run.in_progress?
      'Live now!'
    else
      run.time_to_start_str
    end
  end

  def check_gdq_status
    loop do
      schedule = get_schedule
      run = schedule.current_run

      if run.nil?
        clear_bot_status
        run = schedule.next.first

        if run.nil?
          log.debug('gdq_status: GDQ is not live.')
          sleep_duration = config.max_sleep_time
        else
          log.debug("gdq_status: GDQ is either not live yet or in-between runs.")
          sleep_duration = wait_time(run)
        end
      else
        log.debug("gdq_status: GDQ is live.")
        set_run_status(run)
        sleep_duration = wait_time(run)
      end

      sleep_duration = sleep_duration.clamp(config.min_sleep_time,
                                            config.max_sleep_time)
      sleep_thread(sleep_duration)
    rescue StandardError => err
      log.error(err)
      sleep_thread(config.max_sleep_time)
    end
  end

  def set_run_status(run)
    update_bot_status('online', run.to_s_short, config.stream_url)
  end

  def sleep_thread(sleep_duration)
    log.debug("Sleeping gdq_status thread for #{sleep_duration}s.")
    sleep(sleep_duration)
  end

  def wait_time(run)
    time_left = run.in_progress? ? run.time_to_end : run.time_to_start
    time_left / 2.5
  end
end
