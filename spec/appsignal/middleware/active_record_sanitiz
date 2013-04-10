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

    context "single quoted data value" do
      let(:payload) { "SELECT `table`.* FROM `table` WHERE `id` = 'secret'" }

      it { should == "SELECT `table`.* FROM `table` WHERE `id` = ?" }

      context "with an escaped single quote" do
        let(:payload) { "`id` = '\\'big\\' secret'" }

        it { should == "`id` = ?" }
      end

      context "with an escaped double quote" do
        let(:payload) { "`id` = '\\\"big\\\" secret'" }

        it { should == "`id` = ?" }
      end
    end

    context "double quoted data value" do
      let(:payload) { 'SELECT `table`.* FROM `table` WHERE `id` = "secret"' }

      it { should == 'SELECT `table`.* FROM `table` WHERE `id` = ?' }


      context "with an escaped single quote" do
        let(:payload) { '`id` = "\\\'big\\\' secret"' }

        it { should == "`id` = ?" }
      end

      context "with an escaped double quote" do
        let(:payload) { '`id` = "\\"big\\" secret"' }

        it { should == "`id` = ?" }
      end
    end

    context "numeric parameter" do
      let(:payload) { 'SELECT `table`.* FROM `table` WHERE `id` = 1' }

      it { should == 'SELECT `table`.* FROM `table` WHERE `id` = ?' }
    end

    context "parameter array" do
      let(:payload) { 'SELECT `table`.* FROM `table` WHERE `id` IN (1, 2)' }

      it { should == 'SELECT `table`.* FROM `table` WHERE `id` IN (?)' }
    end
  end
end
