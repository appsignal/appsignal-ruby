RSpec.describe "Puma plugin" do
  include WaitForHelper

  class MockPumaLauncher
    def log_writer
      return @log_writer if defined?(@log_writer)

      @log_writer = MockPumaLogWriter.new
    end
  end

  class MockPumaLogWriter
    attr_reader :logs

    def initialize
      @logs = []
    end

    def log(message)
      @logs << [:log, message]
    end

    def debug(message)
      @logs << [:debug, message]
    end

    def error(message)
      @logs << [:error, message]
    end
  end

  # StatsD server used for these tests.
  # Open a UDPSocket and listen for messages sent by the AppSignal Puma plugin.
  class StatsdServer
    def start
      stop
      @socket = UDPSocket.new
      @socket.bind("127.0.0.1", 8125)

      loop do
        # Listen for messages and track them on the messages Array.
        packet = @socket.recvfrom(1024)
        track_message packet.first
      rescue Errno::EBADF
        # Ignore error for JRuby 9.1.17.0 specifically, it doesn't appear to
        # happen on 9.2.18.0. It doesn't break the tests themselves, ignoring
        # this error. It's probably a timing issue where it tries to read
        # from the socket after it's closed.
      end
    end

    def stop
      defined?(@socket) && @socket && @socket.close
    ensure
      @socket = nil
    end

    def messages
      @messages ||= []
    end

    private

    def track_message(message)
      @messages_mutex ||= Mutex.new
      @messages_mutex.synchronize { messages << message }
    end
  end

  let(:probe) { MockProbe.new }
  let(:launcher) { MockPumaLauncher.new }
  let(:hostname) { Socket.gethostname }
  let(:expected_default_tags) { { "hostname" => hostname } }
  let(:stats_data) { { :backlog => 1 } }
  before :context do
    Appsignal.stop
  end
  before do
    module Puma
      def self.stats
        JSON.dump(@_stats_data)
      end

      def self.stats_hash
        @_stats_data
      end

      def self._set_stats=(data)
        @_stats_data = data
      end

      class Plugin
        class << self
          attr_reader :appsignal_plugin

          def create(&block)
            @appsignal_plugin = Class.new(::Puma::Plugin)
            @appsignal_plugin.class_eval(&block)
          end
        end

        attr_reader :in_background_block

        def in_background(&block)
          @in_background_block = block
        end
      end
    end
    Puma._set_stats = stats_data
    load File.expand_path("../lib/puma/plugin/appsignal.rb", APPSIGNAL_SPEC_DIR)

    @statsd = StatsdServer.new
    @server_thread = Thread.new { @statsd.start }
    @server_thread.abort_on_exception = true
  end
  after do
    @statsd = nil

    Object.send(:remove_const, :Puma)
    Object.send(:remove_const, :AppsignalPumaPlugin)
  end

  def run_plugin(plugin, &block)
    @client_thread = Thread.new { start_plugin(plugin) }
    @client_thread.abort_on_exception = true
    wait_for(:puma_client_wait, &block)
  ensure
    stop_all
  end

  def appsignal_plugin
    Puma::Plugin.appsignal_plugin
  end

  def start_plugin(plugin_class)
    plugin = plugin_class.new
    # Speed up test by not waiting for 60 seconds initial wait time and loop
    # interval.
    allow(plugin).to receive(:sleep_time).and_return(0.01)
    plugin.start(launcher)
    plugin.in_background_block.call
  end

  # Stop all threads in test and stop listening on the UDPSocket
  def stop_all
    @client_thread.kill if defined?(@client_thread) && @client_thread
    @server_thread.kill if defined?(@server_thread) && @server_thread
    @statsd.stop if defined?(@statsd) && @statsd
    @client_thread = nil
    @server_thread = nil
  end

  def logs
    launcher.log_writer.logs
  end

  def messages
    @statsd.messages.map do |message|
      metric, type, tags_string = message.split("|")
      metric_name, metric_value = metric.split(":")
      tags = {}
      tags_string[1..].split(",").each do |tag|
        key, value = tag.split(":")
        tags[key] = value
      end
      {
        :name => metric_name,
        :value => metric_value.to_i,
        :type => type,
        :tags => tags
      }
    end
  end

  def expect_gauge(metric_name, metric_value, tags_hash = {})
    expect(messages).to include(
      :name => "puma_#{metric_name}",
      :value => metric_value,
      :type => "g",
      :tags => expected_default_tags.merge(tags_hash)
    )
  end

  context "with multiple worker stats" do
    let(:stats_data) do
      {
        :workers => 2,
        :booted_workers => 2,
        :old_workers => 0,
        :worker_status => [
          {
            :last_status => {
              :backlog => 0,
              :running => 5,
              :pool_capacity => 5,
              :max_threads => 5
            }
          },
          {
            :last_status => {
              :backlog => 0,
              :running => 5,
              :pool_capacity => 5,
              :max_threads => 5
            }
          }
        ]
      }
    end

    it "collects puma stats as guage metrics with the (summed) worker metrics" do
      run_plugin(appsignal_plugin) do
        expect(logs).to_not include([:error, kind_of(String)])
        expect_gauge(:workers, 2, "type" => "count")
        expect_gauge(:workers, 2, "type" => "booted")
        expect_gauge(:workers, 0, "type" => "old")
        expect_gauge(:connection_backlog, 0)
        expect_gauge(:pool_capacity, 10)
        expect_gauge(:threads, 10, "type" => "running")
        expect_gauge(:threads, 10, "type" => "max")
      end
    end
  end

  context "with single worker stats" do
    let(:stats_data) do
      {
        :backlog => 0,
        :running => 5,
        :pool_capacity => 5,
        :max_threads => 5
      }
    end

    it "calls `puma_gauge` with the (summed) worker metrics" do
      run_plugin(appsignal_plugin) do
        expect(logs).to_not include([:error, kind_of(String)])
        expect_gauge(:connection_backlog, 0)
        expect_gauge(:pool_capacity, 5)
        expect_gauge(:threads, 5, "type" => "running")
        expect_gauge(:threads, 5, "type" => "max")
      end
    end
  end

  context "when using APPSIGNAL_HOSTNAME" do
    let(:hostname) { "my-host-name" }
    before { ENV["APPSIGNAL_HOSTNAME"] = hostname }
    after { ENV.delete("APPSIGNAL_HOSTNAME") }

    it "reports the APPSIGNAL_HOSTNAME as the hostname tag value" do
      run_plugin(appsignal_plugin) do
        expect(logs).to_not include([:error, kind_of(String)])
        expect_gauge(:connection_backlog, 1)
      end
    end
  end

  context "without Puma.stats_hash" do
    before do
      Puma.singleton_class.send(:remove_method, :stats_hash)
    end

    it "fetches metrics from Puma.stats instead" do
      run_plugin(appsignal_plugin) do
        expect(logs).to_not include([:error, kind_of(String)])
        expect(logs).to_not include([kind_of(Symbol), "AppSignal: No Puma stats to report."])
        expect_gauge(:connection_backlog, 1)
      end
    end
  end

  context "without Puma.stats and Puma.stats_hash" do
    before do
      Puma.singleton_class.send(:remove_method, :stats)
      Puma.singleton_class.send(:remove_method, :stats_hash)
    end

    it "does not fetch metrics" do
      run_plugin(appsignal_plugin) do
        expect(logs).to_not include([:error, kind_of(String)])
        expect(logs).to include([:debug, "AppSignal: No Puma stats to report."])
        expect(messages).to be_empty
      end
    end
  end

  context "without running StatsD server" do
    it "does nothing" do
      stop_all
      run_plugin(appsignal_plugin) do
        expect(logs).to_not include([:error, kind_of(String)])
        expect(messages).to be_empty
      end
    end
  end

  context "with Puma < 6 Events class" do
    class MockPumaEvents
      attr_reader :logs

      def initialize
        @logs = []
      end

      def log(message)
        @logs << [:log, message]
      end

      def debug(message)
        @logs << [:debug, message]
      end

      def error(message)
        @logs << [:error, message]
      end
    end

    let(:launcher) do
      Class.new do
        def events
          return @events if defined?(@events)

          @events = MockPumaEvents.new
        end
      end.new
    end
    let(:stats_data) { { :max_threads => 5 } }

    it "logs messages to the events class" do
      run_plugin(appsignal_plugin) do
        expect(launcher.events.logs).to_not be_empty
      end
    end
  end
end
