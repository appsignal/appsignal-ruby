require "appsignal/integrations/object"

describe Object do
  around { |example| keep_transactions { example.run } }

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

      def call_with_arguments
        instance.foo(
          "abc",
          { :foo => "bar" },
          :keyword_param => 2
        )
      end

      context "when active" do
        let(:transaction) { http_request_transaction }
        before do
          start_agent
          set_current_transaction(transaction)
        end

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

          it "instruments the method and calls it" do
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

        context "with anonymous class" do
          it "instruments the method and calls it" do
            expect(call_with_arguments).to eq(["abc", { :foo => "bar" }, 2])

            expect(transaction).to include_event("name" => "foo.AnonymousClass.other")
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
            expect(instance.foo).to eq(1)

            expect(transaction).to include_event("name" => "foo.NamedClass.other")
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
            expect(instance.bar).to eq(2)

            expect(transaction).to include_event(
              "name" => "bar.NamedClass.NestedModule.MyModule.other"
            )
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
            expect(instance.foo).to eq(1)

            expect(transaction).to include_event(
              "name" => "my_method.group"
            )
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

          it "yields the block" do
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
      def call_with_arguments
        klass.bar(
          "abc",
          { :foo => "bar" },
          :keyword_param => 2
        )
      end

      context "when active" do
        let(:transaction) { http_request_transaction }
        before do
          start_agent
          set_current_transaction(transaction)
        end

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

          it "instruments the method and calls it" do
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

        context "with anonymous class" do
          it "instruments the method and calls it" do
            expect(Appsignal.active?).to be_truthy
            expect(call_with_arguments).to eq(["abc", { :foo => "bar" }, 2])

            transaction._sample
            expect(transaction).to include_event("name" => "bar.class_method.AnonymousClass.other")
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
            expect(klass.bar).to eq(2)

            expect(transaction).to include_event("name" => "bar.class_method.NamedClass.other")
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
              expect(klass.bar).to eq(2)
              expect(transaction).to include_event(
                "name" => "bar.class_method.NamedClass.NestedModule.MyModule.other"
              )
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
            expect(klass.bar).to eq(2)

            expect(transaction).to include_event("name" => "my_method.group")
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

          it "yields the block" do
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
