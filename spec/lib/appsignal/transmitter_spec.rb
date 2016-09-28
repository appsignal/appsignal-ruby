describe Appsignal::Transmitter do
  let(:config) { project_fixture_config }
  let(:action) { 'action' }
  let(:log) { StringIO.new }
  let(:instance) { Appsignal::Transmitter.new(action, config) }
  before do
    config.config_hash[:hostname] = 'app1.local'
    config.logger = Logger.new(log)
  end

  describe "#uri" do
    subject { instance.uri.to_s }

    it { should include 'https://push.appsignal.com/1/action?' }
    it { should include 'api_key=abc' }
    it { should include 'hostname=app1.local' }
    it { should include 'name=TestApp' }
    it { should include 'environment=production' }
    it { should include "gem_version=#{Appsignal::VERSION}" }
  end

  describe "#transmit" do
    before do
      stub_request(
        :post,
        "https://push.appsignal.com/1/action?api_key=abc"\
          "&environment=production&gem_version=#{Appsignal::VERSION}"\
          "&hostname=#{config.config_hash[:hostname]}&name=TestApp"
      ).with(
        :body => Appsignal::Utils::Gzip.compress("{\"the\":\"payload\"}"),
        :headers => {
          'Content-Encoding' => 'gzip',
          'Content-Type' => 'application/json; charset=UTF-8',
        }
      ).to_return(
        :status => 200
      )
    end
    subject { instance.transmit(:the => :payload) }

    it { should eq '200' }

    context "with ca_file_path config option set" do
      context "when not existing file" do
        before do
          config.config_hash[:ca_file_path] = File.join(resources_dir, "cacert.pem")
        end

        it "ignores the config and logs a warning" do
          expect(subject).to eq '200'
          expect(log.string).to_not include "Ignoring non-existing or unreadable " \
            "`ca_file_path`: #{config[:ca_file_path]}"
        end
      end

      context "when not existing file" do
        before do
          config.config_hash[:ca_file_path] = File.join(tmp_dir, "ca_file_that_does_not_exist")
        end

        it "ignores the config and logs a warning" do
          expect(subject).to eq '200'
          expect(log.string).to include "Ignoring non-existing or unreadable " \
            "`ca_file_path`: #{config[:ca_file_path]}"
        end
      end

      context "when not readable file" do
        let(:file) { File.join(tmp_dir, "ca_file") }
        before do
          config.config_hash[:ca_file_path] = file
          File.open(file, "w") { |f| f.chmod 0000 }
        end

        it "ignores the config and logs a warning" do
          expect(subject).to eq '200'
          expect(log.string).to include "Ignoring non-existing or unreadable " \
            "`ca_file_path`: #{config[:ca_file_path]}"
        end

        after { File.delete file }
      end
    end
  end

  describe "#http_post" do
    subject { instance.send(:http_post, 'the' => 'payload') }

    its(:body) { should eq Appsignal::Utils::Gzip.compress("{\"the\":\"payload\"}") }
    its(:path) { should eq instance.uri.request_uri }

    it "should have the correct headers" do
      subject['Content-Type'].should eq 'application/json; charset=UTF-8'
      subject['Content-Encoding'].should eq 'gzip'
    end
  end

  describe "#http_client" do
    subject { instance.send(:http_client) }

    context "with a http uri" do
      let(:config) { project_fixture_config('test') }

      it { should be_instance_of(Net::HTTP) }
      its(:proxy?) { should be_false }
      its(:use_ssl?) { should be_false }
    end

    context "with a https uri" do
      let(:config) { project_fixture_config('production') }

      it { should be_instance_of(Net::HTTP) }
      its(:proxy?) { should be_false }
      its(:use_ssl?) { should be_true }
      its(:verify_mode) { should eq OpenSSL::SSL::VERIFY_PEER }
      its(:ca_file) { should eq config[:ca_file_path] }
    end

    context "with a proxy" do
      let(:config) { project_fixture_config('production', :http_proxy => 'http://localhost:8080') }

      its(:proxy?) { should be_true }
      its(:proxy_address) { should eq 'localhost' }
      its(:proxy_port) { should eq 8080 }
    end
  end
end
