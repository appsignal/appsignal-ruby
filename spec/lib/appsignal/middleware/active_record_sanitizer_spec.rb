require 'spec_helper'
require 'active_record'
require 'appsignal/middleware/active_record_sanitizer'

describe Appsignal::Middleware::ActiveRecordSanitizer do
  let(:klass) { Appsignal::Middleware::ActiveRecordSanitizer }
  let(:sql_event_sanitizer) { klass.new }
  let(:connection_config) { {} }
  before do
    if ActiveRecord::Base.respond_to?(:connection_config)
      # Rails 3.1+
      ActiveRecord::Base.stub(
        :connection_config => connection_config
      )
    else
      # Rails 3.0
      spec = double(:config => connection_config)
      ActiveRecord::Base.stub(
        :connection_pool => double(:spec => spec)
      )
    end
  end

  describe "#call" do
    let(:name) { 'Model load' }
    let(:binds) { [] }
    let(:event) do
      notification_event(
        :name => 'sql.active_record',
        :payload => create_payload(
          :name => name,
          :sql => sql,
          :binds => binds,
          :connection_id => 1111
        )
      )
    end
    subject { event.payload[:sql] }
    before { sql_event_sanitizer.call(event) { } }

    context "connection id and bindings" do
      let(:sql) { '' }
      subject { event.payload }

      it { should_not have_key(:connection_id) }
      it { should_not have_key(:binds) }
    end

    context "with backtick table names" do
      before { sql_event_sanitizer.stub(:adapter_uses_double_quoted_table_names? => false) }

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

    context "with double quote style table names and no prepared statements" do
      let(:connection_config) { {:adapter => 'postgresql', :prepared_statements => false} }

      context "single quoted data value" do
        let(:sql) { "SELECT \"table\".* FROM \"table\" WHERE \"id\" = 'secret'" }

        it { should == "SELECT \"table\".* FROM \"table\" WHERE \"id\" = ?" }

        context "with an escaped single quote" do
          let(:sql) { "\"id\" = '\\'big\\' secret'" }

          it { should == "\"id\" = ?" }
        end

        context "with an escaped double quote" do
          let(:sql) { "\"id\" = '\\\"big\\\" secret'" }

          it { should == "\"id\" = ?" }
        end
      end

      context "numeric parameter" do
        let(:sql) { 'SELECT "table".* FROM "table" WHERE "id"=1' }

        it { should == 'SELECT "table".* FROM "table" WHERE "id"=?' }
      end
    end

    context "skip sanitization for prepared statements" do
      let(:connection_config) { {:adapter => 'postgresql'} }

      let(:sql) { 'SELECT "table".* FROM "table" WHERE "id"=$1' }

      it { should == 'SELECT "table".* FROM "table" WHERE "id"=$1' }
    end

    context "skip sanitization for schema queries" do
      let(:name) { 'SCHEMA' }
      let(:sql) { 'SET client_min_messages TO 22' }

      it { should == 'SET client_min_messages TO 22' }
    end
  end

  describe "#schema_query?" do
    let(:payload) { {} }
    let(:event) { notification_event(:payload => payload) }
    subject { sql_event_sanitizer.schema_query?(event) }

    it { should be_false }

    context "when name is schema" do
      let(:payload) { {:name => 'SCHEMA'} }

      it { should be_true }
    end
  end

  context "connection config" do
    describe "#connection_config" do
      let(:connection_config) { {:adapter => 'adapter'} }

      subject { sql_event_sanitizer.connection_config }

      it { should == {:adapter => 'adapter'} }
    end

    describe "#adapter_uses_double_quoted_table_names?" do
      subject { sql_event_sanitizer.adapter_uses_double_quoted_table_names? }

      context "when using mysql" do
        let(:connection_config) { {:adapter => 'mysql'} }

        it { should be_false }
      end

      context "when using postgresql" do
        let(:connection_config) { {:adapter => 'postgresql'} }

        it { should be_true }
      end

      context "when using sqlite" do
        let(:connection_config) { {:adapter => 'sqlite'} }

        it { should be_true }
      end
    end

    describe "adapter_uses_prepared_statements?" do
      subject { sql_event_sanitizer.adapter_uses_prepared_statements? }

      context "when using mysql" do
        let(:connection_config) { {:adapter => 'mysql'} }

        it { should be_false }
      end

      context "when using postgresql" do
        let(:connection_config) { {:adapter => 'postgresql'} }

        it { should be_true }
      end

      context "when using postgresql and prepared statements is disabled" do
        let(:connection_config) { {:adapter => 'postgresql', :prepared_statements => false} }

        it { should be_false }
      end
    end
  end
end
