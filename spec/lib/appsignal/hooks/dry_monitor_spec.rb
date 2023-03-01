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
    before :context do
      start_agent
    end

    let!(:transaction) do
      Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
    end

    let(:notifications) { Dry::Monitor::Notifications.new(:test) }

    context "when is a dry-sql event" do
      let(:event_id) { :sql }
      let(:payload) do
        {
          :name => "postgres",
          :query => "SELECT * FROM users"
        }
      end

      it "creates an sql event" do
        notifications.instrument(event_id, payload)
        expect(transaction.to_h["events"]).to match([
          {
            "allocation_count" => kind_of(Integer),
            "body" => "SELECT * FROM users",
            "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
            "child_allocation_count" => kind_of(Integer),
            "child_duration" => kind_of(Float),
            "child_gc_duration" => kind_of(Float),
            "count" => 1,
            "duration" => kind_of(Float),
            "gc_duration" => kind_of(Float),
            "name" => "query.postgres",
            "start" => kind_of(Float),
            "title" => "query.postgres"
          }
        ])
      end
    end

    context "when is an unregistered formatter event" do
      let(:event_id) { :foo }
      let(:payload) do
        {
          :name => "foo"
        }
      end

      it "creates a generic event" do
        notifications.instrument(event_id, payload)
        expect(transaction.to_h["events"]).to match([
          {
            "allocation_count" => kind_of(Integer),
            "body" => "",
            "body_format" => Appsignal::EventFormatter::DEFAULT,
            "child_allocation_count" => kind_of(Integer),
            "child_duration" => kind_of(Float),
            "child_gc_duration" => kind_of(Float),
            "count" => 1,
            "duration" => kind_of(Float),
            "gc_duration" => kind_of(Float),
            "name" => "foo",
            "start" => kind_of(Float),
            "title" => ""
          }
        ])
      end
    end
  end
end
