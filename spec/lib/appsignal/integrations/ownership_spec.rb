if DependencyHelper.ownership_present?
  require "appsignal/integrations/ownership"

  describe Appsignal::Integrations::OwnershipIntegration do
    let(:start_agent_args) { { :options => config } }
    let(:config) { { :ownership_set_namespace => false } }

    before do
      Ownership.around_change = nil
      Appsignal::Hooks::OwnershipHook.new.install
    end

    context "when the transaction is created within an owner block" do
      describe "adds the owner to the transaction tags" do
        def perform
          owner("owner") do
            @transaction = Appsignal::Transaction.create("namespace")
          end
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          keep_transactions { @transaction.complete }

          expect(@transaction).to include_tags("owner" => "owner")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          @transaction.complete

          expect(root_span.attributes["appsignal.tag.owner"]).to eq("owner")
        end
      end

      it_in_both_modes "does not set the namespace of the transaction to the owner" do
        owner("owner") do
          transaction = Appsignal::Transaction.create("namespace")
          expect(transaction.namespace).to eq("namespace")
        end
      end

      context "when `ownership_set_namespace` config option is enabled" do
        let(:config) { { :ownership_set_namespace => true } }

        it_in_both_modes "sets the namespace of the transaction to the owner" do
          owner("owner") do
            transaction = Appsignal::Transaction.create("namespace")
            expect(transaction.namespace).to eq("owner")
          end
        end
      end
    end

    context "when the owner is changed after a transaction has been created" do
      describe "adds the new owner to the transaction tags" do
        def perform
          @transaction = Appsignal::Transaction.create("namespace")
          owner("owner") { nil }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          keep_transactions { @transaction.complete }

          expect(@transaction).to include_tags("owner" => "owner")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          @transaction.complete

          expect(root_span.attributes["appsignal.tag.owner"]).to eq("owner")
        end
      end

      describe "keeps the owner tag set by the last ownership change" do
        def perform
          @transaction = Appsignal::Transaction.create("namespace")
          owner("first") { nil }
          owner("second") { nil }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          keep_transactions { @transaction.complete }

          expect(@transaction).to include_tags("owner" => "second")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          @transaction.complete

          expect(root_span.attributes["appsignal.tag.owner"]).to eq("second")
        end
      end

      it_in_both_modes "does not set the namespace of the current transaction to the owner" do
        transaction = Appsignal::Transaction.create("namespace")
        owner("owner") do
          expect(transaction.namespace).to eq("namespace")
        end
      end

      context "when `ownership_set_namespace` config option is enabled" do
        let(:config) { { :ownership_set_namespace => true } }

        it_in_both_modes "sets the namespace of the current transaction to the owner" do
          transaction = Appsignal::Transaction.create("namespace")
          expect(transaction.namespace).to eq("namespace")

          owner("owner") do
            expect(transaction.namespace).to eq("owner")
          end
        end

        it_in_both_modes "keeps the namespace given by the last ownership change" do
          owner("owner") do
            transaction = Appsignal::Transaction.create("namespace")

            owner("first") { nil }
            owner("second") { nil }

            expect(transaction.namespace).to eq("second")
          end
        end
      end

      describe "allows the `around_change` hook to be set" do
        def perform
          override = proc do |_owner, block|
            # The `around_change` hook must call `block.call` to actually run
            # the code within the `owner` block, as documented in `ownership`'s
            # README:
            # https://github.com/ankane/ownership/blob/b277ef821654d0e73d2e6c8df4f636932b7a90fa/README.md#custom-integrations
            block.call
          end

          expect(override).to receive(:call).with("owner", kind_of(Proc)).and_call_original

          Ownership.around_change = override

          @transaction = Appsignal::Transaction.create("namespace")

          block = proc {}
          expect(block).to receive(:call)

          owner("owner", &block)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          keep_transactions { @transaction.complete }

          expect(@transaction).to include_tags("owner" => "owner")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          @transaction.complete

          expect(root_span.attributes["appsignal.tag.owner"]).to eq("owner")
        end
      end
    end

    context "when an error is reported in a transaction" do
      describe "sets the owner tag of the transaction to the owner where the error was raised" do
        def perform
          @transaction = Appsignal::Transaction.create("namespace")

          begin
            owner("error") do
              raise "error"
            end
          rescue StandardError => error
            # This owner should be overriden on the tag by the error owner.
            owner("rescue") { nil }

            @transaction.add_error(error)
          end
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          keep_transactions { @transaction.complete }

          expect(@transaction).to include_tags("owner" => "error")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          @transaction.complete

          # The owner tag is driven by the recorded error; assert the exception
          # event that produced it is present.
          event = root_span.events.find { |e| e.name == "exception" }
          expect(event).not_to be_nil
          expect(event.attributes["exception.message"]).to eq("error")
          expect(root_span.attributes["appsignal.tag.owner"]).to eq("error")
        end
      end

      it_in_both_modes "does not set the namespace to the owner where the error was raised" do
        transaction = Appsignal::Transaction.create("namespace")

        begin
          owner("error") do
            raise "error"
          end
        rescue StandardError => error
          owner("rescue") { nil }

          transaction.add_error(error)
          transaction.complete
          expect(transaction.namespace).to eq("namespace")
        end
      end

      context "when `ownership_set_namespace` config option is enabled" do
        let(:config) { { :ownership_set_namespace => true } }

        it_in_both_modes "sets the namespace to the owner where the error was raised" do
          transaction = Appsignal::Transaction.create("namespace")

          begin
            owner("error") do
              raise "error"
            end
          rescue StandardError => error
            # This owner should be overriden on the namespace by the error owner.
            owner("rescue") { nil }
            expect(transaction.namespace).to eq("rescue")

            transaction.add_error(error)
            transaction.complete
            expect(transaction.namespace).to eq("error")
          end
        end
      end
    end

    context "when several errors are reported in a transaction" do
      describe "sets the owner tag of the transaction to the owner where its error was raised" do
        def perform
          @transaction = Appsignal::Transaction.create("namespace")

          begin
            owner("first") do
              raise "first error"
            end
          rescue StandardError => first_error
            # This owner should be overriden on the tag by the error owner.
            owner("first_rescue") { nil }
            @transaction.add_error(first_error)
          end

          begin
            owner("second") do
              raise "second error"
            end
          rescue StandardError => second_error
            # This owner should be overriden on the tag by the error owner.
            owner("second_rescue") { nil }
            @transaction.add_error(second_error)
          end
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          keep_transactions { @transaction.complete }

          expect(created_transactions.length).to eq(2)
          expect(created_transactions.find { |t| t == @transaction })
            .to include_tags("owner" => "first")
          expect(created_transactions.find { |t| t != @transaction })
            .to include_tags("owner" => "second")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          @transaction.complete

          # In collector mode, multiple errors are recorded as exception events
          # on the single root span — no duplicate transactions. The owner tag
          # is set by the `before_complete` hook with the first error's owner.
          root_spans = span_exporter.finished_spans.select do |s|
            [:server, :consumer].include?(s.kind)
          end
          expect(root_spans.size).to eq(1)
          events = root_spans.first.events.select { |e| e.name == "exception" }
          expect(events.map { |e| e.attributes["exception.message"] })
            .to contain_exactly("first error", "second error")
          expect(root_span.attributes["appsignal.tag.owner"]).to eq("first")
        end
      end

      context "when `ownership_set_namespace` config option is enabled" do
        let(:config) { { :ownership_set_namespace => true } }

        describe "sets the namespace of each transaction to the owner where its error was raised" do
          def perform
            @transaction = Appsignal::Transaction.create("namespace")

            begin
              owner("first") do
                raise "first error"
              end
            rescue StandardError => first_error
              # This owner should be overriden on the namespace by the error owner.
              owner("first_rescue") { nil }
              @transaction.add_error(first_error)
            end

            begin
              owner("second") do
                raise "second error"
              end
            rescue StandardError => second_error
              # This owner should be overriden on the namespace by the error owner.
              owner("second_rescue") { nil }
              @transaction.add_error(second_error)
            end
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            perform
            keep_transactions { @transaction.complete }

            expect(created_transactions.length).to eq(2)
            expect(created_transactions.find { |t| t == @transaction }.namespace)
              .to eq("first")
            expect(created_transactions.find { |t| t != @transaction }.namespace)
              .to eq("second")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            @transaction.complete

            # In collector mode there is one trace: the namespace is set by the
            # `before_complete` hook with the first error's owner.
            expect(@transaction.namespace).to eq("first")
          end
        end
      end
    end
  end
end
