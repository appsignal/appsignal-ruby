require "appsignal/probes/pgbus"

describe Appsignal::Probes::PgbusProbe do
  let(:probe) { described_class.new }

  before do
    start_agent

    stub_const("Pgbus::Web::DataSource", Class.new {
      def queues_with_metrics
        [
          {
            :name => "default",
            :queue_length => 42,
            :queue_visible_length => 30,
            :total_messages => 1000,
            :oldest_msg_age_sec => 5.2,
            :paused => false
          },
          {
            :name => "critical",
            :queue_length => 3,
            :queue_visible_length => 3,
            :total_messages => 500,
            :oldest_msg_age_sec => nil,
            :paused => false
          }
        ]
      end

      def processes
        [{ :pid => 1 }, { :pid => 2 }]
      end

      def summary_stats
        { :dlq_depth => 7, :failed_count => 12 }
      end

      def stream_stats_available?
        true
      end

      def stream_stats_summary
        {
          :broadcasts => 150,
          :connects => 20,
          :disconnects => 5,
          :active_estimate => 15,
          :avg_fanout => 3.5
        }
      end
    })
  end

  describe "#call" do
    it "reports queue depth gauges" do
      expect(Appsignal).to receive(:set_gauge)
        .with("pgbus_queue_depth", 42, { :queue => "default" })
      expect(Appsignal).to receive(:set_gauge)
        .with("pgbus_queue_visible_depth", 30, { :queue => "default" })
      expect(Appsignal).to receive(:set_gauge)
        .with("pgbus_queue_oldest_message_age_seconds", 5.2, { :queue => "default" })
      expect(Appsignal).to receive(:set_gauge)
        .with("pgbus_queue_depth", 3, { :queue => "critical" })
      expect(Appsignal).to receive(:set_gauge)
        .with("pgbus_queue_visible_depth", 3, { :queue => "critical" })

      allow(Appsignal).to receive(:set_gauge)

      probe.call
    end

    it "reports process count" do
      expect(Appsignal).to receive(:set_gauge)
        .with("pgbus_active_processes", 2, {})

      allow(Appsignal).to receive(:set_gauge)

      probe.call
    end

    it "reports summary stats" do
      expect(Appsignal).to receive(:set_gauge)
        .with("pgbus_dlq_depth", 7, {})
      expect(Appsignal).to receive(:set_gauge)
        .with("pgbus_failed_events_total", 12, {})

      allow(Appsignal).to receive(:set_gauge)

      probe.call
    end

    it "reports stream metrics when available" do
      expect(Appsignal).to receive(:set_gauge)
        .with("pgbus_stream_broadcasts", 150, {})
      expect(Appsignal).to receive(:set_gauge)
        .with("pgbus_stream_active_connections", 15, {})
      expect(Appsignal).to receive(:set_gauge)
        .with("pgbus_stream_avg_fanout", 3.5, {})

      allow(Appsignal).to receive(:set_gauge)

      probe.call
    end

    context "when stream stats are not available" do
      before do
        allow_any_instance_of(Pgbus::Web::DataSource)
          .to receive(:stream_stats_available?).and_return(false)
      end

      it "skips stream metrics" do
        expect(Appsignal).to_not receive(:set_gauge)
          .with("pgbus_stream_broadcasts", anything, anything)

        allow(Appsignal).to receive(:set_gauge)

        probe.call
      end
    end

    context "when a data source method raises" do
      before do
        allow_any_instance_of(Pgbus::Web::DataSource)
          .to receive(:queues_with_metrics).and_raise(StandardError, "db gone")
      end

      it "continues with other metrics" do
        expect(Appsignal).to receive(:set_gauge)
          .with("pgbus_active_processes", 2, {})
        expect(Appsignal).to receive(:set_gauge)
          .with("pgbus_dlq_depth", 7, {})

        allow(Appsignal).to receive(:set_gauge)

        probe.call
      end
    end
  end
end
