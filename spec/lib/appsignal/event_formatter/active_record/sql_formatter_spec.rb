require 'spec_helper'

if active_record_present?
  require 'active_record'

  describe Appsignal::EventFormatter::ActiveRecord::SqlFormatter do
    let(:klass) { Appsignal::EventFormatter::ActiveRecord::SqlFormatter }
    let(:formatter) { klass.new }
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

    pending "should register sql.activerecord" do
      Appsignal::EventFormatter.registered?('sql.active_record', klass).should be_true
    end

    context "if a connection cannot be established" do
      before do
        ActiveRecord::Base.stub(:connection_config).and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it "should log the error and unregister the formatter" do
        Appsignal.logger.should_receive(:error).with(
          'Error while getting ActiveRecord connection info, unregistering sql.active_record event formatter'
        )

        lambda {
          formatter
        }.should_not raise_error

        Appsignal::EventFormatter.registered?('sql.active_record').should be_false
      end
    end

    describe "#format" do
      let(:name) { 'Model load' }
      let(:payload) { {:sql => sql, :name => name} }
      subject { formatter.format(payload) }

      context "with backtick table names" do
        before { formatter.stub(:adapter_uses_double_quoted_table_names => false) }

        context "single quoted data value" do
          let(:sql) { "SELECT `table`.* FROM `table` WHERE `id` = 'secret' ORDER BY `table`.`id` ASC LIMIT 1" }

          it { should == ['Model load', "SELECT `table`.* FROM `table` WHERE `id` = ? ORDER BY `table`.`id` ASC LIMIT ?"] }

          context "with escaped single quotes in the string" do
            let(:sql) { "`id` = 'this is a \'big\' secret'" }

            it { should == ['Model load', "`id` = ?"] }
          end
        end

        context "double quoted data value" do
          let(:sql) { 'SELECT `table`.* FROM `table` WHERE `id` = "secret"' }

          it { should == ['Model load', 'SELECT `table`.* FROM `table` WHERE `id` = ?'] }

          context "with escaped double quotes in the string" do
            let(:sql) { '`id` = "this is a \"big\" secret"' }

            it { should == ['Model load', "`id` = ?"] }
          end
        end

        context "numeric parameter" do
          context "integer" do
            let(:sql) { 'SELECT `table`.* FROM `table` WHERE `id` = 1' }

            it { should == ['Model load', 'SELECT `table`.* FROM `table` WHERE `id` = ?'] }
          end

          context "float" do
            let(:sql) { 'SELECT `table`.* FROM `table` WHERE `value` = 10.0' }

            it { should == ['Model load', 'SELECT `table`.* FROM `table` WHERE `value` = ?'] }
          end
        end

        context "in operator with values" do
          let(:sql) { 'SELECT `table`.* FROM `table` WHERE `id` IN (1, 2)' }

          it { should == ['Model load', 'SELECT `table`.* FROM `table` WHERE `id` IN (?)'] }
        end

        context "in operator with inner query" do
          let(:sql) { 'SELECT `table`.* FROM `table` WHERE `id` IN (SELECT `id` from `other_table` WHERE `value` = 10.0)' }

          it { should == ['Model load', 'SELECT `table`.* FROM `table` WHERE `id` IN (SELECT `id` from `other_table` WHERE `value` = ?)'] }
        end
      end

      context "with double quote style table names" do
        let(:connection_config) { {:adapter => 'postgresql'} }

        context "single quoted data value" do
          let(:sql) { "SELECT \"table\".* FROM \"table\" WHERE \"id\" = 'secret' ORDER BY \"table\".\"id\" ASC LIMIT 1" }

          it { should == ['Model load', "SELECT \"table\".* FROM \"table\" WHERE \"id\" = ? ORDER BY \"table\".\"id\" ASC LIMIT ?"] }

          context "with an escaped single quote" do
            let(:sql) { "\"id\" = 'this is a \'big\' secret'" }

            it { should == ['Model load', "\"id\" = ?"] }
          end
        end

        context "numeric parameter" do
          context "integer" do
            let(:sql) { 'SELECT "table".* FROM "table" WHERE "id"=1' }

            it { should == ['Model load', 'SELECT "table".* FROM "table" WHERE "id"=?'] }
          end

          context "float" do
            let(:sql) { 'SELECT "table".* FROM "table" WHERE "value"=10.0' }

            it { should == ['Model load', 'SELECT "table".* FROM "table" WHERE "value"=?'] }
          end
        end
      end

      context "return nil for schema queries" do
        let(:name) { 'SCHEMA' }
        let(:sql) { 'SET client_min_messages TO 22' }

        it { should be_nil }
      end

      context "with a a frozen sql string" do
        let(:sql) { "SELECT `table`.* FROM `table` WHERE `id` = 'secret'".freeze }

        it { should == ['Model load', "SELECT `table`.* FROM `table` WHERE `id` = ?"] }
      end
    end

    describe "#schema_query?" do
      let(:payload) { {} }
      subject { formatter.send(:schema_query?, payload) }

      it { should be_false }

      context "when name is schema" do
        let(:payload) { {:name => 'SCHEMA'} }

        it { should be_true }
      end
    end

    context "connection config" do
      describe "#connection_config" do
        let(:connection_config) { {:adapter => 'adapter'} }

        subject { formatter.send(:connection_config) }

        it { should == {:adapter => 'adapter'} }
      end

      describe "#adapter_uses_double_quoted_table_names" do
        subject { formatter.adapter_uses_double_quoted_table_names }

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
    end
  end
end
