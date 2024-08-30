class PumaMock
  module MiniSSL
    class SSLError < StandardError
      def self.to_s
        "Puma::MiniSSL::SSLError"
      end
    end
  end

  class HttpParserError < StandardError
    def self.to_s
      "Puma::HttpParserError"
    end
  end

  class HttpParserError501 < StandardError
    def self.to_s
      "Puma::HttpParserError501"
    end
  end

  def self.stats
  end

  def self.cli_config
    @cli_config ||= CliConfig.new
  end

  class Server
  end

  module Const
    VERSION = "6.0.0".freeze
  end

  class CliConfig
    attr_accessor :options

    def initialize
      @options = {}
    end
  end
end
