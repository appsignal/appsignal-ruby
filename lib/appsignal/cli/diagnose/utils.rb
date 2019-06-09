module Appsignal
  class CLI
    class Diagnose
      class Utils
        def self.username_for_uid(uid)
          passwd_struct = Etc.getpwuid(uid)
          return unless passwd_struct
          passwd_struct.name
        rescue ArgumentError # rubocop:disable Lint/HandleExceptions
        end

        def self.group_for_gid(gid)
          passwd_struct = Etc.getgrgid(gid)
          return unless passwd_struct
          passwd_struct.name
        rescue ArgumentError # rubocop:disable Lint/HandleExceptions
        end

        def self.read_file_content(path, bytes_to_read)
          file_size = File.size(path)
          if bytes_to_read > file_size
            # When the file is smaller than the bytes_to_read
            # Read the whole file
            offset = 0
            length = file_size
          else
            # When the file is smaller than the bytes_to_read
            # Read the last X bytes_to_read
            length = bytes_to_read
            offset = file_size - bytes_to_read
          end

          IO.binread(path, length, offset)
        end

        def self.parse_yaml(contents)
          arguments = [contents]
          if YAML.respond_to? :safe_load
            method = :safe_load
            arguments << \
              if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.6.0")
                # Use keyword params for Ruby 2.6 and up
                { :permitted_classes => [Time] }
              else
                [Time]
              end
          else
            method = :load
          end
          YAML.send(method, *arguments)
        end
      end
    end
  end
end
