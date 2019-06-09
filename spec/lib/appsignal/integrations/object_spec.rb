require "appsignal/integrations/object"

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
        let(:transaction) { http_request_transaction }
        before do
          Appsignal.config = project_fixture_config
          expect(Appsignal::Transaction).to receive(:current).at_least(:once).and_return(transaction)
        end
        after { Appsignal.config = nil }

        context "with anonymous class" do
          it "instruments the method and calls it" do
            expect(Appsignal.active?).to be_truthy
            expect(transaction).to receive(:start_event)
            expect(transaction).to receive(:finish_event).with \
              "foo.AnonymousClass.other", nil, nil, Appsignal::EventFormatter::DEFAULT
            expect(instance.foo).to eq(1)
          end
        end

        context "with named class" do
          before do
            class NamedClass
              def foo
                1
              end
              appsignal_instrument_method :foo
            end
          end
          after { Object.send(:remove_const, :NamedClass) }
          let(:klass) { NamedClass }

          it "instruments the method and calls it" do
            expect(Appsignal.active?).to be_truthy
            expect(transaction).to receive(:start_event)
            expect(transaction).to receive(:finish_event).with \
              "foo.NamedClass.other", nil, nil, Appsignal::EventFormatter::DEFAULT
            expect(instance.foo).to eq(1)
          end
        end

        context "with nested named class" do
          before do
            module MyModule
              module NestedModule
                class NamedClass
                  def bar
                    2
                  end
                  appsignal_instrument_method :bar
                end
              end
            end
          end
          after { Object.send(:remove_const, :MyModule) }
          let(:klass) { MyModule::NestedModule::NamedClass }

          it "instruments the method and calls it" do
            expect(Appsignal.active?).to be_truthy
            expect(transaction).to receive(:start_event)
            expect(transaction).to receive(:finish_event).with \
              "bar.NamedClass.NestedModule.MyModule.other", nil, nil,
              Appsignal::EventFormatter::DEFAULT
            expect(instance.bar).to eq(2)
          end
        end

        context "with custom name" do
          let(:klass) do
            Class.new do
              def foo
                1
              end
              appsignal_instrument_method :foo, :name => "my_method.group"
            end
          end

          it "instruments with custom name" do
            expect(Appsignal.active?).to be_truthy
            expect(transaction).to receive(:start_event)
            expect(transaction).to receive(:finish_event).with \
              "my_method.group", nil, nil, Appsignal::EventFormatter::DEFAULT
            expect(instance.foo).to eq(1)
          end
        end

        context "with a method given a block" do
          let(:klass) do
            Class.new do
              def foo
                yield
              end
              appsignal_instrument_method :foo
            end
          end

          it "should yield the block" do
            expect(instance.foo { 42 }).to eq(42)
          end
        end
      end

      context "when not active" do
        let(:transaction) { Appsignal::Transaction.current }

        it "should not instrument, but still call the method" do
          expect(Appsignal.active?).to be_falsy
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
        let(:transaction) { http_request_transaction }
        before do
          Appsignal.config = project_fixture_config
          expect(Appsignal::Transaction).to receive(:current).at_least(:once)
            .and_return(transaction)
        end
        after { Appsignal.config = nil }

        context "with anonymous class" do
          it "instruments the method and calls it" do
            expect(Appsignal.active?).to be_truthy
            expect(transaction).to receive(:start_event)
            expect(transaction).to receive(:finish_event).with \
              "bar.class_method.AnonymousClass.other", nil, nil, Appsignal::EventFormatter::DEFAULT
            expect(klass.bar).to eq(2)
          end
        end

        context "with named class" do
          before do
            class NamedClass
              def self.bar
                2
              end
              appsignal_instrument_class_method :bar
            end
          end
          after { Object.send(:remove_const, :NamedClass) }
          let(:klass) { NamedClass }

          it "instruments the method and calls it" do
            expect(Appsignal.active?).to be_truthy
            expect(transaction).to receive(:start_event)
            expect(transaction).to receive(:finish_event).with \
              "bar.class_method.NamedClass.other", nil, nil, Appsignal::EventFormatter::DEFAULT
            expect(klass.bar).to eq(2)
          end

          context "with nested named class" do
            before do
              module MyModule
                module NestedModule
                  class NamedClass
                    def self.bar
                      2
                    end
                    appsignal_instrument_class_method :bar
                  end
                end
              end
            end
            after { Object.send(:remove_const, :MyModule) }
            let(:klass) { MyModule::NestedModule::NamedClass }

            it "instruments the method and calls it" do
              expect(Appsignal.active?).to be_truthy
              expect(transaction).to receive(:start_event)
              expect(transaction).to receive(:finish_event).with \
                "bar.class_method.NamedClass.NestedModule.MyModule.other", nil, nil,
                Appsignal::EventFormatter::DEFAULT
              expect(klass.bar).to eq(2)
            end
          end
        end

        context "with custom name" do
          let(:klass) do
            Class.new do
              def self.bar
                2
              end
              appsignal_instrument_class_method :bar, :name => "my_method.group"
            end
          end

          it "instruments with custom name" do
            expect(Appsignal.active?).to be_truthy
            expect(transaction).to receive(:start_event)
            expect(transaction).to receive(:finish_event).with \
              "my_method.group", nil, nil, Appsignal::EventFormatter::DEFAULT
            expect(klass.bar).to eq(2)
          end
        end

        context "with a method given a block" do
          let(:klass) do
            Class.new do
              def self.bar
                yield
              end
              appsignal_instrument_class_method :bar
            end
          end

          it "should yield the block" do
            expect(klass.bar { 42 }).to eq(42)
          end
        end
      end

      context "when not active" do
        let(:transaction) { Appsignal::Transaction.current }

        it "should not instrument, but still call the method" do
          expect(Appsignal.active?).to be_falsy
          expect(transaction).to_not receive(:start_event)
          expect(klass.bar).to eq(2)
        end
      end
    end
  end
end
