if DependencyHelper.code_ownership_present?
  require "appsignal/integrations/code_ownership"

  describe Appsignal::Integrations::CodeOwnershipIntegration do
    def create_config_file
      yaml_config =
        <<~CONFIG
          owned_globs:
            - '{app,config}/**/*.{rb,rake,js,jsx,ts,tsx}'
          js_package_paths: []
        CONFIG

      write_file(File.join(tmp_dir, "config", "code_ownership.yml"), yaml_config)
    end

    def create_team_files
      file_team =
        <<~CONFIG
          name: FileTeam
        CONFIG

      write_file(File.join(tmp_dir, "config", "teams", "file.yml"), file_team)

      dir_team =
        <<~CONFIG
          name: DirectoryTeam
        CONFIG

      write_file(File.join(tmp_dir, "config", "teams", "directory.yml"), dir_team)

      glob_team =
        <<~CONFIG
          name: GlobTeam
          owned_globs:
            - #{File.join(support_dir, "code_ownership", "glob", "*.rb")}
        CONFIG

      write_file(File.join(tmp_dir, "config", "teams", "glob.yml"), glob_team)
    end

    before do
      start_agent

      Appsignal::Hooks::CodeOwnershipHook.new.install
    end

    context "when an error is reported in a transaction" do
      after do
        FileUtils.rm_rf(File.join(tmp_dir, "config"))
      end

      it "handles missing config file" do
        transaction = create_transaction

        begin
          require File.join(support_dir, "code_ownership", "file_annotation_based.rb")
        rescue => error
          transaction.add_error(error)
        ensure
          expect { keep_transactions { transaction.complete } }.not_to raise_error
        end
      end

      it "handles missing team config files" do
        create_config_file
        transaction = create_transaction

        begin
          require File.join(support_dir, "code_ownership", "file_annotation_based.rb")
        rescue => error
          transaction.add_error(error)
        ensure
          expect { keep_transactions { transaction.complete } }.not_to raise_error
        end
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
            require File.join(support_dir, "code_ownership", "file_annotation_based.rb")
          rescue => error
            transaction.add_error(error)
          ensure
            keep_transactions { transaction.complete }
          end

          expect(transaction).to include_tags("owner" => "FileTeam")
        end

        it "sets an owner tag of the transaction based on directory ownership" do
          transaction = create_transaction

          begin
            require File.join(support_dir, "code_ownership", "dir", "directory_based.rb")
          rescue => error
            transaction.add_error(error)
          ensure
            keep_transactions { transaction.complete }
          end

          expect(transaction).to include_tags("owner" => "DirectoryTeam")
        end

        it "sets owner tag of the transaction based on `owned_globs` in team.yml file" do
          transaction = create_transaction

          begin
            require File.join(support_dir, "code_ownership", "glob", "glob_based.rb")
          rescue => error
            transaction.add_error(error)
          ensure
            keep_transactions { transaction.complete }
          end

          expect(transaction).to include_tags("owner" => "GlobTeam")
        end
      end
    end
  end
end
