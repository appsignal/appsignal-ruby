if DependencyHelper.code_ownership_present?
  require "appsignal/integrations/code_ownership"

  describe Appsignal::Integrations::CodeOwnershipIntegration do
    before do
      Appsignal::Hooks::CodeOwnershipHook.new.install
    end

    around { |example| keep_transactions { example.run } }

    after do
      CodeOwnership.bust_caches!
    end

    context "when an error is reported in a transaction" do
      after do
        FileUtils.rm_rf(File.join(tmp_dir, "config"))
      end

      # These examples exercise the error-handling path and assert on
      # internal_logger output, which is not OTel-routed. No collector coverage.
      it "handles missing config file" do
        start_agent
        create_app_files
        transaction = create_transaction

        logs = capture_logs do
          load File.join(tmp_dir, "app", "file_annotation_based.rb")
        rescue => error
          transaction.add_error(error)
        ensure
          transaction.complete
        end

        expect(transaction).to_not include_tags("owner" => anything)
        expect(logs).to contains_log(
          :error,
          "Error while looking up CodeOwnership team"
        )
      end

      it "handles missing team config files" do
        start_agent
        create_app_files
        create_config_file
        transaction = create_transaction

        logs = capture_logs do
          load File.join(tmp_dir, "app", "file_annotation_based.rb")
        rescue => error
          transaction.add_error(error)
        ensure
          transaction.complete
        end

        expect(transaction).to_not include_tags("owner" => anything)
        expect(logs).to contains_log(
          :error,
          "Error while looking up CodeOwnership team"
        )
      end

      context "and config is set up correctly" do
        before do
          create_app_files
          create_config_file
          create_team_files
        end

        around do |example|
          Dir.chdir tmp_dir do
            example.run
          end
        end

        after do
          FileUtils.rm_rf(File.join(tmp_dir, "config"))
        end

        describe "sets an owner tag of the transaction based on file-annotation" do
          let(:transaction) { create_transaction }

          def perform
            load File.join(tmp_dir, "app", "file_annotation_based.rb")
          rescue => error
            transaction.add_error(error)
          ensure
            transaction.complete
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform
            transaction._sample

            expect(transaction).to include_tags("owner" => "FileTeam")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            # The owner lookup is driven by the recorded error; assert the
            # exception event that produced it is present.
            event = root_span.events.find { |e| e.name == "exception" }
            expect(event).not_to be_nil
            expect(event.attributes["exception.type"]).to eq("RuntimeError")
            expect(root_span.attributes["appsignal.tag.owner"]).to eq("FileTeam")
          end
        end

        describe "sets an owner tag of the transaction based on directory ownership" do
          let(:transaction) { create_transaction }

          def perform
            load File.join(tmp_dir, "app", "dir", "directory_based.rb")
          rescue => error
            transaction.add_error(error)
          ensure
            transaction.complete
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform
            transaction._sample

            expect(transaction).to include_tags("owner" => "DirectoryTeam")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            # The owner lookup is driven by the recorded error; assert the
            # exception event that produced it is present.
            event = root_span.events.find { |e| e.name == "exception" }
            expect(event).not_to be_nil
            expect(event.attributes["exception.type"]).to eq("RuntimeError")
            expect(root_span.attributes["appsignal.tag.owner"]).to eq("DirectoryTeam")
          end
        end

        describe "sets owner tag of the transaction based on `owned_globs` in team.yml file" do
          let(:transaction) { create_transaction }

          def perform
            load File.join(tmp_dir, "app", "glob", "glob_based.rb")
          rescue => error
            transaction.add_error(error)
          ensure
            transaction.complete
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform
            transaction._sample

            expect(transaction).to include_tags("owner" => "GlobTeam")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            # The owner lookup is driven by the recorded error; assert the
            # exception event that produced it is present.
            event = root_span.events.find { |e| e.name == "exception" }
            expect(event).not_to be_nil
            expect(event.attributes["exception.type"]).to eq("RuntimeError")
            expect(root_span.attributes["appsignal.tag.owner"]).to eq("GlobTeam")
          end
        end

        # These examples assert on both tag absence and internal_logger output
        # (no log emitted). No collector coverage for logging behavior.
        it "handles files without owners" do
          start_agent
          transaction = create_transaction

          logs = capture_logs do
            load File.join(tmp_dir, "app", "no_owner.rb")
          rescue => error
            transaction.add_error(error)
          ensure
            transaction.complete
          end

          expect(transaction).to_not include_tags("owner" => anything)
          expect(logs).to be_empty
        end

        it "handles transactions without errors" do
          start_agent
          transaction = create_transaction

          logs = capture_logs do
            transaction.complete
          end

          expect(transaction).to_not include_tags("owner" => anything)
          expect(logs).to be_empty
        end
      end
    end

    private

    def create_app_files
      FileUtils.cp_r(
        File.join(support_dir, "code_ownership", "app"),
        File.join(tmp_dir)
      )
    end

    def create_config_file
      FileUtils.mkdir(File.join(tmp_dir, "config"))
      FileUtils.copy_file(
        File.join(support_dir, "code_ownership", "config", "code_ownership.yml"),
        File.join(tmp_dir, "config", "code_ownership.yml")
      )
    end

    def create_team_files
      FileUtils.cp_r(
        File.join(support_dir, "code_ownership", "config", "teams"),
        File.join(tmp_dir, "config")
      )
    end
  end
end
