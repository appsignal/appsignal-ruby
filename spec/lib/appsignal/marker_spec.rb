describe Appsignal::Marker do
  let(:config) { project_fixture_config }
  let(:marker) {
    Appsignal::Marker.new(
      {
        :revision => '503ce0923ed177a3ce000005',
        :repository => 'master',
        :user => 'batman',
        :rails_env => 'production'
      },
      config
    )
  }
  let(:out_stream) { StringIO.new }
  around do |example|
    capture_stdout(out_stream) { example.run }
  end

  context "transmit" do
    let(:transmitter) { double }
    before do
      Appsignal::Transmitter.should_receive(:new).with(
        'markers', config
      ).and_return(transmitter)
    end

    it "should transmit data" do
      transmitter.should_receive(:transmit).with(
        :revision => '503ce0923ed177a3ce000005',
        :repository => 'master',
        :user => 'batman',
        :rails_env => 'production'
      )

      marker.transmit
    end

    it "should log status 200" do
      transmitter.should_receive(:transmit).and_return('200')

      marker.transmit

      out_stream.string.should include('Notifying Appsignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman')
      out_stream.string.should include('Appsignal has been notified of this deploy!')
    end

    it "should log other status" do
      transmitter.should_receive(:transmit).and_return('500')
      transmitter.should_receive(:uri).and_return('http://localhost:3000/1/markers')

      marker.transmit

      out_stream.string.should include('Notifying Appsignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman')
      out_stream.string.should include(
        'Something went wrong while trying to notify Appsignal: 500 at http://localhost:3000/1/markers'
      )
      out_stream.string.should_not include(
        'Appsignal has been notified of this deploy!'
      )
    end
  end
end
