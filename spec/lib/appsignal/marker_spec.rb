describe Appsignal::Marker do
  let(:config) { project_fixture_config }
  let(:marker) do
    described_class.new(
      {
        :revision => "503ce0923ed177a3ce000005",
        :repository => "main",
        :user => "batman",
        :rails_env => "production"
      },
      config
    )
  end
  let(:out_stream) { std_stream }
  let(:output) { out_stream.read }

  describe "#transmit" do
    def stub_marker_request
      stub_api_request config, "markers", marker.marker_data
    end

    def run
      capture_stdout(out_stream) { marker.transmit }
    end

    context "when request is valid" do
      before { stub_marker_request.to_return(:status => 200) }

      it "outputs success" do
        run
        expect(output).to include \
          "Notifying AppSignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman",
          "AppSignal has been notified of this deploy!"
      end
    end

    context "when request is invalid" do
      before { stub_marker_request.to_return(:status => 500) }

      it "outputs failure" do
        run
        expect(output).to include \
          "Notifying AppSignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman",
          "Something went wrong while trying to notify AppSignal: 500 at " \
            "#{config[:endpoint]}/1/markers"
        expect(output).to_not include \
          "AppSignal has been notified of this deploy!"
      end
    end
  end
end
