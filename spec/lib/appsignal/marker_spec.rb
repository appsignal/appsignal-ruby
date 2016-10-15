describe Appsignal::Marker do
  let(:config) { project_fixture_config }
  let(:marker) do
    described_class.new(
      {
        :revision => '503ce0923ed177a3ce000005',
        :repository => 'master',
        :user => 'batman',
        :rails_env => 'production'
      },
      config
    )
  end
  let(:out_stream) { StringIO.new }
  around do |example|
    capture_stdout(out_stream) { example.run }
  end

  describe "#transmit" do
    def stub_marker_request
      stub_api_request config, "markers", marker.marker_data
    end

    context "when request is valid" do
      before do
        stub_marker_request.to_return(:status => 200)
        marker.transmit
      end

      it "outputs success" do
        output = out_stream.string
        expect(output).to include \
          'Notifying AppSignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman',
          'AppSignal has been notified of this deploy!'
      end
    end

    context "when request is invalid" do
      before do
        stub_marker_request.to_return(:status => 500)
        marker.transmit
      end

      it "outputs failure" do
        output = out_stream.string
        expect(output).to include \
          'Notifying AppSignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman',
          "Something went wrong while trying to notify AppSignal: 500 at "\
          "#{config[:endpoint]}/1/markers"
        expect(output).to_not include \
          'AppSignal has been notified of this deploy!'
      end
    end
  end
end
