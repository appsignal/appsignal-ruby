require 'appsignal/cli'

describe Appsignal::CLI::Diagnose do
  let(:out_stream) { StringIO.new }
  let(:cli) { Appsignal::CLI::Diagnose }
  around do |example|
    original_stdout = $stdout
    $stdout = out_stream
    example.run
    $stdout = original_stdout
  end

  describe ".run" do
    it "should output diagnostic information" do
      cli.run
      output = out_stream.string
      expect(output).to include('Gem version')
      expect(output).to include('Agent version')
      expect(output).to include('Environment')
      expect(output).to include('Config')
      expect(output).to include('Checking API key')
      expect(output).to include('Checking if required paths are writable')
      expect(output).to include('Showing last lines of extension install log')
    end
  end
end
