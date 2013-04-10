require 'spec_helper'

describe Appsignal::Middleware::ActiveRecordSanitizer do
  let(:klass) { Appsignal::Middleware::ActiveRecordSanitizer }
  let(:sql_event_sanitizer) { klass.new }

  describe "#call" do
    let(:event) do
      notification_event(
        :name => 'sql.active_record',
        :payload => create_payload(
          :sql => sql,
          :connection_id => 1111
        )
      )
    end
    subject { event.payload[:sql] }
    before { sql_event_sanitizer.call(event) { } }

    context "connection id" do
      let(:sql) { '' }
      subject { event.payload }

      it { should_not have_key(:connection_id) }
    end

    context "single quoted data value" do
      let(:sql) { "SELECT `table`.* FROM `table` WHERE `id` = 'secret'" }

      it { should == "SELECT `table`.* FROM `table` WHERE `id` = ?" }

      context "with an escaped single quote" do
        let(:sql) { "`id` = '\\'big\\' secret'" }

        it { should == "`id` = ?" }
      end

      context "with an escaped double quote" do
        let(:sql) { "`id` = '\\\"big\\\" secret'" }

        it { should == "`id` = ?" }
      end
    end

    context "double quoted data value" do
      let(:sql) { 'SELECT `table`.* FROM `table` WHERE `id` = "secret"' }

      it { should == 'SELECT `table`.* FROM `table` WHERE `id` = ?' }

      context "with an escaped single quote" do
        let(:sql) { '`id` = "\\\'big\\\' secret"' }

        it { should == "`id` = ?" }
      end

      context "with an escaped double quote" do
        let(:sql) { '`id` = "\\"big\\" secret"' }

        it { should == "`id` = ?" }
      end
    end

    context "numeric parameter" do
      let(:sql) { 'SELECT `table`.* FROM `table` WHERE `id` = 1' }

      it { should == 'SELECT `table`.* FROM `table` WHERE `id` = ?' }
    end

    context "parameter array" do
      let(:sql) { 'SELECT `table`.* FROM `table` WHERE `id` IN (1, 2)' }

      it { should == 'SELECT `table`.* FROM `table` WHERE `id` IN (?)' }
    end
  end
end
