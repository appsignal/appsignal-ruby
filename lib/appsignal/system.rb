module Appsignal
  # System environment detection module.
  #
  # Provides useful methods to find out more about the host system.
  #
  # @api private
  module System
    # @return [Boolean]
    def self.container?
      heroku? || Container.id
    end

    # Returns `true` if AppSignal detects it's running on a Heroku dyno.
    # @see http://heroku.com Heroku
    # @return [Boolean]
    def self.heroku?
      ENV.key? "DYNO".freeze
    end

    # Container detection helper.
    #
    # Reads and parses the system's cgroup file and tries to find signs of a
    # containerized system.
    module Container
      # Location of the cgropu file used to detect container systems.
      CGROUP_FILE = "/proc/self/cgroup".freeze

      class << self
        # Returns container id if a container is detected.
        #
        # @return [String]
        # @return [nil] no container id found.
        def id
          case cgroups
          when %r{docker[-|/]([0-9a-f]+)}
            $1
          when %r{lxc/([0-9a-f-]+)$} # LXC / Heroku
            $1
          end
        end

        private

        def cgroups
          file = CGROUP_FILE
          return unless File.exist? file

          File.read(file)
        rescue SystemCallError => e
          Appsignal.logger.debug "Unable to read '#{file}' to determine cgroup"
          Appsignal.logger.debug e
        end
      end
    end
  end
end
