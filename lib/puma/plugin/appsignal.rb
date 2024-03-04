# frozen_string_literal: true

require "json"

# AppSignal Puma plugin
#
# This plugin ensures Puma metrics are sent to the AppSignal agent using StatsD.
#
# For even more information:
# https://docs.appsignal.com/ruby/integrations/puma.html
Puma::Plugin.create do # rubocop:disable Metrics/BlockLength
  def start(launcher)
    @launcher = launcher
    log_debug "AppSignal: Puma plugin start."
    in_background do
      log_debug "AppSignal: Start Puma stats collection loop."
      plugin = AppsignalPumaPlugin.new

      loop do
        # Implement similar behavior to minutely probes.
        # Initial sleep to wait until the app is fully initialized.
        # Then loop every 60 seconds and collect the Puma stats as AppSignal
        # metrics.
        sleep sleep_time

        log_debug "AppSignal: Collecting Puma stats."
        stats = fetch_puma_stats
        if stats
          plugin.call(stats)
        else
          log_debug "AppSignal: No Puma stats to report."
        end
      rescue StandardError => error
        log_error "Error while processing metrics.", error
      end
    end
  end

  private

  def sleep_time
    60 # seconds
  end

  def logger
    if @launcher.respond_to? :log_writer
      @launcher.log_writer
    else
      @launcher.events
    end
  end

  def log_debug(message)
    logger.debug message
  end

  def log_error(message, error)
    logger.error "AppSignal: #{message}\n" \
      "#{error.class}: #{error.message}\n#{error.backtrace.join("\n")}"
  end

  def fetch_puma_stats
    if Puma.respond_to? :stats_hash # Puma >= 5.0.0
      Puma.stats_hash
    elsif Puma.respond_to? :stats # Puma < 5.0.0
      # Puma.stats_hash returns symbolized keys as well
      JSON.parse Puma.stats, :symbolize_names => true
    end
  rescue StandardError => error
    log_error "Error while parsing Puma stats.", error
    nil
  end
end

# AppsignalPumaPlugin
#
# Class to handle the logic of translating the Puma stats to AppSignal metrics.
#
# @api private
class AppsignalPumaPlugin
  def initialize
    @hostname = fetch_hostname
    @statsd = Statsd.new
  end

  def call(stats)
    counts = {}
    count_keys = [:backlog, :running, :pool_capacity, :max_threads]

    if stats[:worker_status] # Clustered mode - Multiple workers
      stats[:worker_status].each do |worker|
        stat = worker[:last_status]
        count_keys.each do |key|
          count_if_present counts, key, stat
        end
      end

      gauge(:workers, stats[:workers], :type => :count)
      gauge(:workers, stats[:booted_workers], :type => :booted)
      gauge(:workers, stats[:old_workers], :type => :old)
    else # Single mode - Single worker
      count_keys.each do |key|
        count_if_present counts, key, stats
      end
    end

    gauge(:connection_backlog, counts[:backlog]) if counts[:backlog]
    gauge(:pool_capacity, counts[:pool_capacity]) if counts[:pool_capacity]
    gauge(:threads, counts[:running], :type => :running) if counts[:running]
    gauge(:threads, counts[:max_threads], :type => :max) if counts[:max_threads]
  end

  private

  attr_reader :hostname

  def fetch_hostname
    # Configure hostname as reported for the Puma metrics with the
    # APPSIGNAL_HOSTNAME environment variable.
    env_hostname = ENV.fetch("APPSIGNAL_HOSTNAME", nil)
    return env_hostname if env_hostname

    # Auto detect hostname as fallback. May be inaccurate.
    Socket.gethostname
  end

  def gauge(field, count, tags = {})
    @statsd.gauge("puma_#{field}", count, tags.merge(:hostname => hostname))
  end

  def count_if_present(counts, key, stats)
    stat_value = stats[key]
    return unless stat_value

    counts[key] ||= 0
    counts[key] += stat_value
  end

  class Statsd
    def initialize
      # StatsD server location as configured in AppSignal agent StatsD server.
      @host = "127.0.0.1"
      @port = ENV.fetch("APPSIGNAL_STATSD_PORT", 8125)
    end

    def gauge(metric_name, value, tags)
      send_metric "g", metric_name, value, tags
    end

    private

    attr_reader :host, :port

    def send_metric(type, metric_name, metric_value, tags_hash)
      tags = tags_hash.map { |key, value| "#{key}:#{value}" }.join(",")
      data = "#{metric_name}:#{metric_value}|#{type}|##{tags}"

      # Open (and close) a new socket every time because we don't know when the
      # plugin will exit and when to cleanly close the socket connection.
      socket = UDPSocket.new
      socket.send(data, 0, host, port)
    ensure
      socket&.close
    end
  end
end
