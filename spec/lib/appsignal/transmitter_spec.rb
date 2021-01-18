describe Appsignal::Transmitter do
  let(:config) { project_fixture_config }
  let(:base_uri) { "action" }
  let(:log) { StringIO.new }
  let(:instance) { Appsignal::Transmitter.new(base_uri, config) }
  before do
    config.config_hash[:hostname] = "app1.local"
    config.logger = Logger.new(log)
  end

  describe "#uri" do
    let(:uri) { instance.uri }

    it "returns a URI object with configuration data" do
      expect(uri.to_s).to start_with(config[:endpoint])
      expect(uri.path).to eq("/1/action")
      expect(CGI.parse(uri.query)).to eq(
        "api_key" => ["abc"],
        "hostname" => ["app1.local"],
        "name" => ["TestApp"],
        "environment" => ["production"],
        "gem_version" => [Appsignal::VERSION]
      )
    end

    context "when base_uri argument is a full URI" do
      let(:base_uri) { "http://foo.bar/path" }

      it "uses the full URI" do
        expect(uri.to_s).to start_with("#{base_uri}?")
      end
    end

    context "when base_uri argument is only a path" do
      it "uses the config[:endpoint] base" do
        expect(uri.to_s).to start_with("#{config[:endpoint]}/1/#{base_uri}?")
      end
    end
  end

  describe "#transmit" do
    before do
      stub_request(:post, "https://push.appsignal.com/1/action").with(
        :query => {
          :api_key => "abc",
          :environment => "production",
          :gem_version => Appsignal::VERSION,
          :hostname => config[:hostname],
          :name => "TestApp"
        },
        :body => "{\"the\":\"payload\"}",
        :headers => {
          "Content-Type" => "application/json; charset=UTF-8"
        }
      ).to_return(:status => 200)
    end
    let(:response) { instance.transmit(:the => :payload) }

    it "returns Net::HTTP response" do
      expect(response).to be_kind_of(Net::HTTPResponse)
      expect(response.code).to eq "200"
    end

    context "with ca_file_path config option set" do
      context "when file does not exist" do
        before do
          config.config_hash[:ca_file_path] = File.join(resources_dir, "cacert.pem")
        end

        it "ignores the config and logs a warning" do
          expect(response).to be_kind_of(Net::HTTPResponse)
          expect(response.code).to eq "200"
          expect(log.string).to_not include "Ignoring non-existing or unreadable " \
            "`ca_file_path`: #{config[:ca_file_path]}"
        end
      end

      context "when not existing file" do
        before do
          config.config_hash[:ca_file_path] = File.join(tmp_dir, "ca_file_that_does_not_exist")
        end

        it "ignores the config and logs a warning" do
          expect(response).to be_kind_of(Net::HTTPResponse)
          expect(response.code).to eq "200"
          expect(log.string).to include "Ignoring non-existing or unreadable " \
            "`ca_file_path`: #{config[:ca_file_path]}"
        end
      end

      context "when not readable file" do
        let(:file) { File.join(tmp_dir, "ca_file") }
        before do
          config.config_hash[:ca_file_path] = file
          File.open(file, "w") { |f| f.chmod 0o000 }
        end

        it "ignores the config and logs a warning" do
          expect(response).to be_kind_of(Net::HTTPResponse)
          expect(response.code).to eq "200"
          expect(log.string).to include "Ignoring non-existing or unreadable " \
            "`ca_file_path`: #{config[:ca_file_path]}"
        end

        after { File.delete file }
      end
    end
  end

  describe "#http_post" do
    subject { instance.send(:http_post, "the" => "payload") }

    it "sets the path" do
      expect(subject.path).to eq instance.uri.request_uri
    end

    it "sets the correct headers" do
      expect(subject["Content-Type"]).to eq "application/json; charset=UTF-8"
    end
  end

  describe "#http_client" do
    subject { instance.send(:http_client) }

    context "with a http uri" do
      let(:config) { project_fixture_config("test") }

      it { expect(subject).to be_instance_of(Net::HTTP) }
      it { expect(subject.proxy?).to be_falsy }
      it { expect(subject.use_ssl?).to be_falsy }
    end

    context "with a https uri" do
      let(:config) { project_fixture_config("production") }

      it { expect(subject).to be_instance_of(Net::HTTP) }
      it { expect(subject.proxy?).to be_falsy }
      it { expect(subject.use_ssl?).to be_truthy }
      it { expect(subject.verify_mode).to eq OpenSSL::SSL::VERIFY_PEER }
      it { expect(subject.ca_file).to eq config[:ca_file_path] }
    end

    context "with a proxy" do
      let(:config) { project_fixture_config("production", :http_proxy => "http://localhost:8080") }

      it "is of Net::HTTP class" do
        expect(subject).to be_instance_of(Net::HTTP)
      end
      it { expect(subject.proxy?).to be_truthy }
      it { expect(subject.proxy_address).to eq "localhost" }
      it { expect(subject.proxy_port).to eq 8080 }
    end
  end
end
