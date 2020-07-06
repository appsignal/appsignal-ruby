require "appsignal/integrations/resque"

describe "Legacy Resque integration" do
  let(:err_stream) { std_stream }
  let(:stderr) { err_stream.read }
  let(:log_stream) { std_stream }
  let(:log) { log_contents(log_stream) }

  it "logs and prints a deprecation message on extend" do
    Appsignal.logger = test_logger(log_stream)

    capture_std_streams(std_stream, err_stream) do
      Class.new do
        extend Appsignal::Integrations::ResquePlugin
      end
    end

    deprecation_message =
      "The AppSignal ResquePlugin is deprecated and does " \
      "nothing on extend. In this version of the AppSignal Ruby gem " \
      "the integration with Resque is automatic on all Resque workers. " \
      "Please remove the following line from this file to remove this " \
      "message: extend Appsignal::Integrations::ResquePlugin\n" \
      "#{__FILE__}:"
    expect(stderr).to include "appsignal WARNING: #{deprecation_message}"
    expect(log).to contains_log :warn, deprecation_message
  end
end
