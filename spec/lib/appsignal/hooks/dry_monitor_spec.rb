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
        expect(transaction).to include_event(
          "body" => "SELECT * FROM users",
          "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
          "count" => 1,
          "name" => "query.postgres",
          "title" => "query.postgres"
        )
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
        expect(transaction).to include_event(
          "body" => "",
          "body_format" => Appsignal::EventFormatter::DEFAULT,
          "count" => 1,
          "name" => "foo",
          "title" => ""
        )
      end
    end
  end
end
