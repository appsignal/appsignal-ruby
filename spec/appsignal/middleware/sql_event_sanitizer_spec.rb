require 'spec_helper'

describe Appsignal::Middleware::SqlEventSanitizer do
  let(:klass) { Appsignal::Middleware::SqlEventSanitizer }
  let(:sql_event_sanitizer) { klass.new }

  describe "#call" do
    let(:event) do
      notification_event(
        :name => klass::TARGET_EVENT_NAME,
        :payload => create_payload(:sql => payload)
      )
    end
    subject { event.payload[:sql] }
    before { sql_event_sanitizer.call(event) { } }

    context "with single quoted string parameters" do
      let(:payload) { 'SELECT `table`.* FROM `table` WHERE `id` = \'secret\'' }

      it { should == 'SELECT `table`.* FROM `table` WHERE `id` = ?' }
    end

    context "with double quoted string parameters" do
      let(:payload) { 'SELECT `table`.* FROM `table` WHERE `id` = "secret"' }

      it { should == 'SELECT `table`.* FROM `table` WHERE `id` = ?' }
    end

    context "with numeric parameters" do
      let(:payload) { 'SELECT `table`.* FROM `table` WHERE `id` = 1' }

      it { should == 'SELECT `table`.* FROM `table` WHERE `id` = ?' }
    end
  end
end
