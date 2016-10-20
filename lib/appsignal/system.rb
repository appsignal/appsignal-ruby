module Appsignal
  module System
    def self.container?
      heroku? || Container.id
    end

    def self.heroku?
      ENV.key? 'DYNO'.freeze
    end

    module Container
      CGROUP_FILE = '/proc/self/cgroup'.freeze

      def self.id
        case cgroups
        when %r{docker[-|/]([0-9a-f]+)}
          $1
        when %r{lxc/([0-9a-f-]+)$} # LXC / Heroku
          $1
        end
      end

      private

      def self.cgroups
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
