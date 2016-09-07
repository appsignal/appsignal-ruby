require 'appsignal/cli'

describe Appsignal::CLI::Diagnose do
  let(:out_stream) { StringIO.new }
  let(:cli) { Appsignal::CLI::Diagnose }
  before do
    @original_stdout = $stdout
    $stdout = out_stream
  end
  after do
    $stdout = @original_stdout
  end

  describe ".run" do
    it "should output diagnostic information" do
      cli.run

      out_stream.string.should include('Gem version')
      out_stream.string.should include('Agent version')
      out_stream.string.should include('Environment')
      out_stream.string.should include('Config')
      out_stream.string.should include('Checking API key')
      out_stream.string.should include('Checking if required paths are writable')
      out_stream.string.should include('Showing last lines of extension install log')
    end
  end
end
