require "appsignal/cli/helpers"

module CLIHelpers
  def cli
    Appsignal::CLI
  end

  def run_cli(command, options = {})
    cli.run(format_cli_arguments_and_options(command, options))
  end

  def format_cli_arguments_and_options(command, options = {})
    [*command].tap do |o|
      options.each do |key, value|
        o << (value.nil? ? "--#{key}" : "--#{key}=#{value}")
      end
    end
  end

  def add_cli_input(value)
    $stdin.puts value
  end

  def prepare_cli_input
    # Prepare the input by rewinding the pointer in the StringIO
    $stdin.rewind
  end

  def colorize(*args)
    ColorizeHelper.colorize(*args)
  end
end

module ColorizeHelper
  extend Appsignal::CLI::Helpers

  def self.colorize(*_args)
    super
  end
end
