# frozen_string_literal: true

if DependencyHelper.dry_monitor_present?
  require "dry-monitor"

  describe Appsignal::Hooks::DryMonitorHook do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      context "when Dry::Monitor::Notifications constant is found" do
        before { stub_const "Dry::Monitor::Notifications", Class.new }

        it { is_expected.to be_truthy }
      end

      context "when Dry::Monitor::Notifications constant is not found" do
        before { hide_const "Dry::Monitor::Notifications" }

        it { is_expected.to be_falsy }
      end
    end
  end

  describe "#install" do
    it "installs the dry-monitor hook" do
      start_agent

      expect(Dry::Monitor::Notifications.included_modules).to include(
        Appsignal::Integrations::DryMonitorIntegration
      )
    end
  end

  describe "Dry Monitor Integration" do
    let(:notifications) { Dry::Monitor::Notifications.new(:test) }

    describe "a SQL event" do
      let(:event_id) { :sql }
      let(:payload) do
        {
          :name => "postgres",
          :query => "SELECT * FROM users"
        }
      end

      def perform
        notifications.instrument(event_id, payload)
      end

      it "in agent mode", :agent_mode do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        expect(transaction).to include_event(
          "body" => "SELECT * FROM users",
          "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
          "count" => 1,
          "name" => "query.postgres",
          "title" => "query.postgres"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = event_spans.first
        expect(span.name).to eq("query.postgres")
        expect(span.parent_span_id).to eq(root_span.span_id)
        # ROM emits its queries as dry-monitor `sql` events; a query is an
        # outgoing call, so it carries CLIENT kind.
        expect(span.kind).to eq(:client)
        attrs = span.attributes
        expect(attrs["db.query.text"]).to eq("SELECT * FROM users")
        expect(attrs["db.system.name"]).to eq("other_sql")
        expect(event_category(span)).to eq("query.postgres")
        expect(attrs).not_to have_key("appsignal.body")
      end
    end

    describe "an unregistered formatter event" do
      let(:event_id) { :foo }
      let(:payload) { { :name => "foo" } }

      def perform
        notifications.instrument(event_id, payload)
      end

      it "in agent mode", :agent_mode do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        expect(transaction).to include_event(
          "body" => "",
          "body_format" => Appsignal::EventFormatter::DEFAULT,
          "count" => 1,
          "name" => "foo",
          "title" => ""
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = event_spans.first
        expect(span.name).to eq("foo")
        expect(span.parent_span_id).to eq(root_span.span_id)
        # A non-SQL dry event is not an outgoing call, so it keeps the default kind.
        expect(span.kind).to eq(:internal)
        attrs = span.attributes
        expect(event_category(span)).to eq("foo")
        expect(attrs).not_to have_key("appsignal.body")
        expect(attrs).not_to have_key("db.query.text")
        expect(attrs).not_to have_key("db.system.name")
      end
    end
  end
end
