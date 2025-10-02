if DependencyHelper.code_ownership_present?
  require "appsignal/integrations/code_ownership"

  describe Appsignal::Integrations::CodeOwnershipIntegration do
    before do
      start_agent

      Appsignal::Hooks::CodeOwnershipHook.new.install
    end

    around { |example| keep_transactions { example.run } }

    context "when an error is reported in a transaction" do
      after do
        FileUtils.rm_rf(File.join(tmp_dir, "config"))
      end

      it "handles missing config file" do
        transaction = create_transaction

        logs = capture_logs do
          load File.join(support_dir, "code_ownership", "file_annotation_based.rb")
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
        create_config_file
        transaction = create_transaction

        logs = capture_logs do
          load File.join(support_dir, "code_ownership", "file_annotation_based.rb")
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

        it "sets an owner tag of the transaction based on file-annotation" do
          transaction = create_transaction

          begin
            load File.join(support_dir, "code_ownership", "file_annotation_based.rb")
          rescue => error
            transaction.add_error(error)
          ensure
            transaction.complete
          end

          expect(transaction).to include_tags("owner" => "FileTeam")
        end

        it "sets an owner tag of the transaction based on directory ownership" do
          transaction = create_transaction

          begin
            load File.join(support_dir, "code_ownership", "dir", "directory_based.rb")
          rescue => error
            transaction.add_error(error)
          ensure
            transaction.complete
          end

          expect(transaction).to include_tags("owner" => "DirectoryTeam")
        end

        it "sets owner tag of the transaction based on `owned_globs` in team.yml file" do
          transaction = create_transaction

          begin
            load File.join(support_dir, "code_ownership", "glob", "glob_based.rb")
          rescue => error
            transaction.add_error(error)
          ensure
            transaction.complete
          end

          expect(transaction).to include_tags("owner" => "GlobTeam")
        end

        it "handles files without owners" do
          transaction = create_transaction

          logs = capture_logs do
            load File.join(support_dir, "code_ownership", "no_owner.rb")
          rescue => error
            transaction.add_error(error)
          ensure
            transaction.complete
          end

          expect(transaction).to_not include_tags("owner" => anything)
          expect(logs).to be_empty
        end

        it "handles transactions without errors" do
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

    def create_config_file
      FileUtils.mkdir(File.join(tmp_dir, "config"))
      FileUtils.copy_file(
        File.join(support_dir, "code_ownership", "config", "code_ownership.yml"),
        File.join(tmp_dir, "config", "code_ownership.yml")
      )
    end

    def create_team_files
      FileUtils.mkdir(File.join(tmp_dir, "config", "teams"))

      %w[file directory].each do |team|
        FileUtils.copy_file(
          File.join(support_dir, "code_ownership", "config", "teams", "#{team}.yml"),
          File.join(tmp_dir, "config", "teams", "#{team}.yml")
        )
      end

      glob_team =
        <<~CONFIG
          name: GlobTeam
          owned_globs:
            - #{File.join(support_dir, "code_ownership", "glob", "*.rb")}
        CONFIG

      write_file(File.join(tmp_dir, "config", "teams", "glob.yml"), glob_team)
    end
  end
end
