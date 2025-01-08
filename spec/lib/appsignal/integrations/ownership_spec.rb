if DependencyHelper.ownership_present?
  require "appsignal/integrations/ownership"

  describe Appsignal::Integrations::OwnershipIntegration do
    let(:config) { { :ownership_set_namespace => false } }

    before do
      Ownership.around_change = nil

      start_agent(:options => config)

      Appsignal::Hooks::OwnershipHook.new.install
    end

    context "when the transaction is created within an owner block" do
      it "adds the owner to the transaction tags" do
        transaction = nil
        owner("owner") do
          transaction = Appsignal::Transaction.create("namespace")
        end

        keep_transactions { transaction.complete }

        expect(transaction).to include_tags("owner" => "owner")
      end

      it "does not set the namespace of the transaction to the owner" do
        transaction = nil
        owner("owner") do
          transaction = Appsignal::Transaction.create("namespace")
          expect(transaction.namespace).to eq("namespace")
        end
      end

      context "when `ownership_set_namespace` config option is enabled" do
        let(:config) { { :ownership_set_namespace => true } }

        it "sets the namespace of the transaction to the owner" do
          owner("owner") do
            transaction = Appsignal::Transaction.create("namespace")
            expect(transaction.namespace).to eq("owner")
          end
        end
      end
    end

    context "when the owner is changed after a transaction has been created" do
      it "adds the new owner to the transaction tags" do
        transaction = Appsignal::Transaction.create("namespace")

        owner("owner") do
          keep_transactions { transaction.complete }
          expect(transaction).to include_tags("owner" => "owner")
        end
      end

      it "keeps the owner tag set by the last ownership change" do
        transaction = Appsignal::Transaction.create("namespace")

        owner("first") do
          nil
        end

        owner("second") do
          nil
        end

        keep_transactions { transaction.complete }
        expect(transaction).to include_tags("owner" => "second")
      end

      it "does not set the namespace of the current transaction to the owner" do
        transaction = Appsignal::Transaction.create("namespace")

        owner("owner") do
          expect(transaction.namespace).to eq("namespace")
        end
      end

      context "when `ownership_set_namespace` config option is enabled" do
        let(:config) { { :ownership_set_namespace => true } }

        it "sets the namespace of the current transaction to the owner" do
          transaction = Appsignal::Transaction.create("namespace")
          expect(transaction.namespace).to eq("namespace")

          owner("owner") do
            expect(transaction.namespace).to eq("owner")
          end
        end

        it "keeps the namespace given by the last ownership change" do
          owner("owner") do
            transaction = Appsignal::Transaction.create("namespace")

            owner("first") do
              nil
            end

            owner("second") do
              nil
            end

            expect(transaction.namespace).to eq("second")
          end
        end
      end

      it "allows the `around_change` hook to be set" do
        override = proc do |_owner, block|
          # The `around_change` hook must call `block.call` to actually run
          # the code within the `owner` block, as documented in `ownership`'s
          # README:
          # https://github.com/ankane/ownership/blob/b277ef821654d0e73d2e6c8df4f636932b7a90fa/README.md#custom-integrations
          block.call
        end

        expect(override).to receive(:call).with("owner", kind_of(Proc)).and_call_original

        Ownership.around_change = override

        transaction = Appsignal::Transaction.create("namespace")

        block = proc {}
        expect(block).to receive(:call)

        owner("owner", &block)

        keep_transactions { transaction.complete }
        expect(transaction).to include_tags("owner" => "owner")
      end
    end

    context "when an error is reported in a transaction" do
      it "sets the owner tag of the transaction to the owner where the error was raised" do
        transaction = Appsignal::Transaction.create("namespace")

        begin
          owner("error") do
            raise "error"
          end
        rescue StandardError => error
          # This owner should be overriden on the tag by the error owner.
          owner("rescue") do
            nil
          end

          transaction.add_error(error)
          keep_transactions { transaction.complete }
          expect(transaction).to include_tags("owner" => "error")
        end
      end

      it "does not set the namespace of the transaction to the owner where the error was raised" do
        transaction = Appsignal::Transaction.create("namespace")

        begin
          owner("error") do
            raise "error"
          end
        rescue StandardError => error
          owner("rescue") do
            nil
          end

          transaction.add_error(error)
          transaction.complete
          expect(transaction.namespace).to eq("namespace")
        end
      end

      context "when `ownership_set_namespace` config option is enabled" do
        let(:config) { { :ownership_set_namespace => true } }

        it "sets the namespace of the transaction to the owner where the error was raised" do
          transaction = Appsignal::Transaction.create("namespace")

          begin
            owner("error") do
              raise "error"
            end
          rescue StandardError => error
            # This owner should be overriden on the namespace by the error owner.
            owner("rescue") do
              nil
            end
            expect(transaction.namespace).to eq("rescue")

            transaction.add_error(error)
            transaction.complete
            expect(transaction.namespace).to eq("error")
          end
        end
      end
    end

    context "when several errors are reported in a transaction" do
      it "sets the owner tag of the transaction to the owner where its error was raised" do
        transaction = Appsignal::Transaction.create("namespace")

        begin
          owner("first") do
            raise "first error"
          end
        rescue StandardError => first_error
          # This owner should be overriden on the tag by the error owner.
          owner("first_rescue") do
            nil
          end

          transaction.add_error(first_error)
        end

        begin
          owner("second") do
            raise "second error"
          end
        rescue StandardError => second_error
          # This owner should be overriden on the tag by the error owner.
          owner("second_rescue") do
            nil
          end

          transaction.add_error(second_error)
        end

        keep_transactions { transaction.complete }

        expect(created_transactions.length).to eq(2)
        expect(created_transactions.find do |t|
                 t == transaction
               end).to include_tags("owner" => "first")
        expect(created_transactions.find do |t|
                 t != transaction
               end).to include_tags("owner" => "second")
      end

      context "when `ownership_set_namespace` config option is enabled" do
        let(:config) { { :ownership_set_namespace => true } }

        it "sets the namespace of each transaction to the owner where its error was raised" do
          transaction = Appsignal::Transaction.create("namespace")

          begin
            owner("first") do
              raise "first error"
            end
          rescue StandardError => first_error
            # This owner should be overriden on the namespace by the error owner.
            owner("first_rescue") do
              nil
            end

            transaction.add_error(first_error)
          end

          begin
            owner("second") do
              raise "second error"
            end
          rescue StandardError => second_error
            # This owner should be overriden on the namespace by the error owner.
            owner("second_rescue") do
              nil
            end

            transaction.add_error(second_error)
          end

          transaction.complete

          expect(created_transactions.length).to eq(2)
          expect(created_transactions.find { |t| t == transaction }.namespace).to eq("first")
          expect(created_transactions.find { |t| t != transaction }.namespace).to eq("second")
        end
      end
    end
  end
end
