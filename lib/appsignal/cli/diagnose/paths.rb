# frozen_string_literal: true

module Appsignal
  class CLI
    class Diagnose
      class Paths
        BYTES_TO_READ_FOR_FILES = 2 * 1024 * 1024 # 2 Mebibytes

        def report
          {}.tap do |hash|
            paths.each do |filename, config|
              hash[filename] = path_stat(config[:path])
            end
          end
        end

        def paths
          @paths ||=
            begin
              config = Appsignal.config
              log_file_path = config.log_file_path
              makefile_log_path = File.join("ext", "mkmf.log")
              {
                :package_install_path => {
                  :label => "AppSignal gem path",
                  :path => gem_path
                },
                :working_dir => {
                  :label => "Current working directory",
                  :path => Dir.pwd
                },
                :root_path => {
                  :label => "Root path",
                  :path => config.root_path
                },
                :log_dir_path => {
                  :label => "Log directory",
                  :path => log_file_path ? File.dirname(log_file_path) : ""
                },
                makefile_log_path => {
                  :label => "Makefile install log",
                  :path => File.join(gem_path, makefile_log_path)
                },
                "appsignal.log" => {
                  :label => "AppSignal log",
                  :path => log_file_path
                }
              }
            end
        end

        private

        def path_stat(path)
          {
            :path => path,
            :exists => File.exist?(path)
          }.tap do |info|
            next unless info[:exists]

            stat = File.stat(path)
            info[:type] = stat.directory? ? "directory" : "file"
            info[:mode] = format("%o", stat.mode)
            info[:writable] = stat.writable?
            path_uid = stat.uid
            path_gid = stat.gid
            info[:ownership] = {
              :uid => path_uid,
              :user => Utils.username_for_uid(path_uid),
              :gid => path_gid,
              :group => Utils.group_for_gid(path_gid)
            }
            if info[:type] == "file"
              info[:content] = Utils.read_file_content(
                path,
                BYTES_TO_READ_FOR_FILES
              ).split("\n")
            end
          end
        end

        # Returns the AppSignal gem installation path. The root directory of
        # this gem.
        def gem_path
          File.expand_path("../../../..", __dir__)
        end
      end
    end
  end
end
