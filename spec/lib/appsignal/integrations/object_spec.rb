require 'spec_helper'
require 'appsignal/integrations/object'

describe Object do
  describe "#instrument_method" do
    context "with instance method" do
      let(:klass) do
        Class.new do
          def foo
            1
          end
          appsignal_instrument_method :foo
        end
      end
      let(:instance) { klass.new }

      context "when active" do
        let(:transaction) { regular_transaction }
        before { Appsignal.config = project_fixture_config }
        after { Appsignal.config = nil }

        it "instruments the method and calls it" do
          expect(Appsignal.active?).to be_true
          transaction.should_receive(:start_event)
          transaction.should_receive(:finish_event).with(
            "foo",
            nil,
            nil,
            0
          )
          expect(instance.foo).to eq(1)
        end
      end

      context "when not active" do
        let(:transaction) { Appsignal::Transaction.current }

        it "should not instrument, but still call the method" do
          expect(Appsignal.active?).to be_false
          expect(transaction).to_not receive(:start_event)
          expect(instance.foo).to eq(1)
        end
      end
    end

    context "with class method" do
      let(:klass) do
        Class.new do
          def self.bar
            2
          end
          appsignal_instrument_class_method :bar
        end
      end

      context "when active" do
        let(:transaction) { regular_transaction }
        before { Appsignal.config = project_fixture_config }
        after { Appsignal.config = nil }

        it "instruments the method and calls it" do
          expect(Appsignal.active?).to be_true
          transaction.should_receive(:start_event)
          transaction.should_receive(:finish_event).with(
            "bar",
            nil,
            nil,
            0
          )
          expect(klass.bar).to eq(2)
        end
      end

      context "when not active" do
        let(:transaction) { Appsignal::Transaction.current }

        it "should not instrument, but still call the method" do
          expect(Appsignal.active?).to be_false
          expect(transaction).to_not receive(:start_event)
          expect(klass.bar).to eq(2)
        end
      end
    end
  end
end
