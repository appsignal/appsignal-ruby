require "appsignal/integrations/object"

describe Object do
  describe "#instrument_method" do
    context "with instance method" do
      let(:klass) do
        Class.new do
          def foo(param1, options = {}, keyword_param: 1)
            [param1, options, keyword_param]
          end
          appsignal_instrument_method :foo
        end
      end
      let(:instance) { klass.new }
      let(:transaction) { http_request_transaction }

      def call_with_arguments
        instance.foo(
          "abc",
          { :foo => "bar" },
          :keyword_param => 2
        )
      end

      context "when active" do
        context "with different kind of arguments" do
          let(:klass) do
            Class.new do
              def positional_arguments(param1, param2)
                [param1, param2]
              end
              appsignal_instrument_method :positional_arguments

              def positional_arguments_splat(*params)
                params
              end
              appsignal_instrument_method :positional_arguments_splat

              # rubocop:disable Naming/MethodParameterName
              def keyword_arguments(a: nil, b: nil)
                [a, b]
              end
              # rubocop:enable Naming/MethodParameterName
              appsignal_instrument_method :keyword_arguments

              def keyword_arguments_splat(**kwargs)
                kwargs
              end
              appsignal_instrument_method :keyword_arguments_splat

              def splat(*args, **kwargs)
                [args, kwargs]
              end
              appsignal_instrument_method :splat
            end
          end

          # Asserts only on return values, which are identical in both modes.
          it_in_both_modes "instruments the method and calls it" do
            set_current_transaction(transaction)

            expect(instance.positional_arguments("abc", "def")).to eq(["abc", "def"])
            expect(instance.positional_arguments_splat("abc", "def")).to eq(["abc", "def"])
            expect(instance.keyword_arguments(:a => "a", :b => "b")).to eq(["a", "b"])
            expect(instance.keyword_arguments_splat(:a => "a", :b => "b"))
              .to eq(:a => "a", :b => "b")

            expect(instance.splat).to eq([[], {}])
            expect(instance.splat(:a => "a", :b => "b")).to eq([[], { :a => "a", :b => "b" }])
            expect(instance.splat("abc", "def")).to eq([["abc", "def"], {}])
            expect(instance.splat("abc", "def", :a => "a", :b => "b"))
              .to eq([["abc", "def"], { :a => "a", :b => "b" }])
          end
        end

        describe "with anonymous class" do
          def perform
            expect(call_with_arguments).to eq(["abc", { :foo => "bar" }, 2])
          end

          it "in agent mode", :agent_mode do
            start_agent
            set_current_transaction(transaction)
            perform

            expect(transaction).to include_event("name" => "foo.AnonymousClass.other")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            set_current_transaction(transaction)
            perform
            Appsignal::Transaction.complete_current!

            expect(event_spans.size).to eq(1)
            expect(event_spans.first.parent_span_id).to eq(root_span.span_id)
            expect(event_spans.first.name).to eq("foo.AnonymousClass.other")
          end
        end

        describe "with named class" do
          before do
            stub_const("NamedClass", Class.new do
              def foo
                1
              end
              appsignal_instrument_method :foo
            end)
          end
          let(:klass) { NamedClass }

          def perform
            expect(instance.foo).to eq(1)
          end

          it "in agent mode", :agent_mode do
            start_agent
            set_current_transaction(transaction)
            perform

            expect(transaction).to include_event("name" => "foo.NamedClass.other")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            set_current_transaction(transaction)
            perform
            Appsignal::Transaction.complete_current!

            expect(event_spans.size).to eq(1)
            expect(event_spans.first.parent_span_id).to eq(root_span.span_id)
            expect(event_spans.first.name).to eq("foo.NamedClass.other")
          end
        end

        describe "with nested named class" do
          before do
            stub_const("MyModule::NestedModule::NamedClass", Class.new do
              def bar
                2
              end
              appsignal_instrument_method :bar
            end)
          end
          let(:klass) { MyModule::NestedModule::NamedClass }

          def perform
            expect(instance.bar).to eq(2)
          end

          it "in agent mode", :agent_mode do
            start_agent
            set_current_transaction(transaction)
            perform

            expect(transaction).to include_event(
              "name" => "bar.NamedClass.NestedModule.MyModule.other"
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            set_current_transaction(transaction)
            perform
            Appsignal::Transaction.complete_current!

            expect(event_spans.size).to eq(1)
            expect(event_spans.first.parent_span_id).to eq(root_span.span_id)
            expect(event_spans.first.name).to eq("bar.NamedClass.NestedModule.MyModule.other")
          end
        end

        describe "with custom name" do
          let(:klass) do
            Class.new do
              def foo
                1
              end
              appsignal_instrument_method :foo, :name => "my_method.group"
            end
          end

          def perform
            expect(instance.foo).to eq(1)
          end

          it "in agent mode", :agent_mode do
            start_agent
            set_current_transaction(transaction)
            perform

            expect(transaction).to include_event("name" => "my_method.group")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            set_current_transaction(transaction)
            perform
            Appsignal::Transaction.complete_current!

            expect(event_spans.size).to eq(1)
            expect(event_spans.first.parent_span_id).to eq(root_span.span_id)
            expect(event_spans.first.name).to eq("my_method.group")
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

          # Asserts only on the yielded return value, identical in both modes.
          it_in_both_modes "yields the block" do
            set_current_transaction(transaction)

            expect(instance.foo { 42 }).to eq(42)
          end
        end
      end

      context "when not active" do
        let(:transaction) { Appsignal::Transaction.current }

        it "does not instrument, but still calls the method" do
          expect(Appsignal.active?).to be_falsy
          expect(call_with_arguments).to eq(["abc", { :foo => "bar" }, 2])
        end
      end
    end

    context "with class method" do
      let(:klass) do
        Class.new do
          def self.bar(param1, options = {}, keyword_param: 1)
            [param1, options, keyword_param]
          end
          appsignal_instrument_class_method :bar
        end
      end
      let(:transaction) { http_request_transaction }

      def call_with_arguments
        klass.bar(
          "abc",
          { :foo => "bar" },
          :keyword_param => 2
        )
      end

      context "when active" do
        context "with different kind of arguments" do
          let(:klass) do
            Class.new do
              def self.positional_arguments(param1, param2)
                [param1, param2]
              end
              appsignal_instrument_class_method :positional_arguments

              def self.positional_arguments_splat(*params)
                params
              end
              appsignal_instrument_class_method :positional_arguments_splat

              # rubocop:disable Naming/MethodParameterName
              def self.keyword_arguments(a: nil, b: nil)
                [a, b]
              end
              # rubocop:enable Naming/MethodParameterName
              appsignal_instrument_class_method :keyword_arguments

              def self.keyword_arguments_splat(**kwargs)
                kwargs
              end
              appsignal_instrument_class_method :keyword_arguments_splat

              def self.splat(*args, **kwargs)
                [args, kwargs]
              end
              appsignal_instrument_class_method :splat
            end
          end

          # Asserts only on return values, which are identical in both modes.
          it_in_both_modes "instruments the method and calls it" do
            set_current_transaction(transaction)

            expect(klass.positional_arguments("abc", "def")).to eq(["abc", "def"])
            expect(klass.positional_arguments_splat("abc", "def")).to eq(["abc", "def"])
            expect(klass.keyword_arguments(:a => "a", :b => "b")).to eq(["a", "b"])
            expect(klass.keyword_arguments_splat(:a => "a", :b => "b"))
              .to eq(:a => "a", :b => "b")

            expect(klass.splat).to eq([[], {}])
            expect(klass.splat(:a => "a", :b => "b")).to eq([[], { :a => "a", :b => "b" }])
            expect(klass.splat("abc", "def")).to eq([["abc", "def"], {}])
            expect(klass.splat("abc", "def", :a => "a", :b => "b"))
              .to eq([["abc", "def"], { :a => "a", :b => "b" }])
          end
        end

        describe "with anonymous class" do
          def perform
            expect(Appsignal.active?).to be_truthy
            expect(call_with_arguments).to eq(["abc", { :foo => "bar" }, 2])
          end

          it "in agent mode", :agent_mode do
            start_agent
            set_current_transaction(transaction)
            perform

            transaction._sample
            expect(transaction).to include_event("name" => "bar.class_method.AnonymousClass.other")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            set_current_transaction(transaction)
            perform
            Appsignal::Transaction.complete_current!

            expect(event_spans.size).to eq(1)
            expect(event_spans.first.parent_span_id).to eq(root_span.span_id)
            expect(event_spans.first.name).to eq("bar.class_method.AnonymousClass.other")
          end
        end

        describe "with named class" do
          before do
            stub_const("NamedClass", Class.new do
              def self.bar
                2
              end
              appsignal_instrument_class_method :bar
            end)
          end
          let(:klass) { NamedClass }

          def perform
            expect(Appsignal.active?).to be_truthy
            expect(klass.bar).to eq(2)
          end

          it "in agent mode", :agent_mode do
            start_agent
            set_current_transaction(transaction)
            perform

            expect(transaction).to include_event("name" => "bar.class_method.NamedClass.other")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            set_current_transaction(transaction)
            perform
            Appsignal::Transaction.complete_current!

            expect(event_spans.size).to eq(1)
            expect(event_spans.first.parent_span_id).to eq(root_span.span_id)
            expect(event_spans.first.name).to eq("bar.class_method.NamedClass.other")
          end

          context "with nested named class" do
            before do
              stub_const("MyModule::NestedModule::NamedClass", Class.new do
                def self.bar
                  2
                end
                appsignal_instrument_class_method :bar
              end)
            end
            let(:klass) { MyModule::NestedModule::NamedClass }

            it "in agent mode", :agent_mode do
              start_agent
              set_current_transaction(transaction)
              perform

              expect(transaction).to include_event(
                "name" => "bar.class_method.NamedClass.NestedModule.MyModule.other"
              )
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              set_current_transaction(transaction)
              perform
              Appsignal::Transaction.complete_current!

              expect(event_spans.size).to eq(1)
              expect(event_spans.first.parent_span_id).to eq(root_span.span_id)
              expect(event_spans.first.name)
                .to eq("bar.class_method.NamedClass.NestedModule.MyModule.other")
            end
          end
        end

        describe "with custom name" do
          let(:klass) do
            Class.new do
              def self.bar
                2
              end
              appsignal_instrument_class_method :bar, :name => "my_method.group"
            end
          end

          def perform
            expect(Appsignal.active?).to be_truthy
            expect(klass.bar).to eq(2)
          end

          it "in agent mode", :agent_mode do
            start_agent
            set_current_transaction(transaction)
            perform

            expect(transaction).to include_event("name" => "my_method.group")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            set_current_transaction(transaction)
            perform
            Appsignal::Transaction.complete_current!

            expect(event_spans.size).to eq(1)
            expect(event_spans.first.parent_span_id).to eq(root_span.span_id)
            expect(event_spans.first.name).to eq("my_method.group")
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

          # Asserts only on the yielded return value, identical in both modes.
          it_in_both_modes "yields the block" do
            set_current_transaction(transaction)

            expect(klass.bar { 42 }).to eq(42)
          end
        end
      end

      context "when not active" do
        let(:transaction) { Appsignal::Transaction.current }

        it "does not instrument, but still call the method" do
          expect(Appsignal.active?).to be_falsy
          expect(call_with_arguments).to eq(["abc", { :foo => "bar" }, 2])
        end
      end
    end
  end
end
