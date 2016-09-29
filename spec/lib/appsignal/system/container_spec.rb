describe Appsignal::System::Container do
  describe ".id" do
    subject { described_class.id }

    context "when in docker" do
      context "when running normally" do
        around { |example| recognize_as_container(:docker) { example.run } }

        it "returns id" do
          expect(subject).to eq("0c703b75cdeaad7c933aa68b4678cc5c37a12d5ef5d7cb52c9cefe684d98e575")
        end
      end

      context "when running with systemd" do
        around do |example|
          # Fabricated example. I'm unable to set up an environment that
          # produces such a cgroups file.
          recognize_as_container(:docker_systemd) { example.run }
        end

        it "returns id" do
          expect(subject).to eq("09f1c4d420025670a3633edbc9b31450f1d6b2ff87b5912a10c320ad398c7215")
        end
      end
    end

    context "when in LXC" do
      around { |example| recognize_as_container(:lxc) { example.run } }

      it "returns id" do
        expect(subject).to eq("1a2e485e-3947-4bb6-8c24-8774f0859648")
      end
    end

    context "when not in container" do
      around { |example| recognize_as_container(:none) { example.run } }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when no permission to read cgroup file" do
      let(:out_stream) { StringIO.new }
      let(:no_permission_file) do
        File.join(fixtures_dir, 'containers', 'cgroups', 'no_permission')
      end
      before do
        File.chmod 0333, no_permission_file
        Appsignal.logger = Logger.new(out_stream)
      end
      around { |example| recognize_as_container(:no_permission) { example.run } }
      after { File.chmod 0644, no_permission_file }

      it "returns nil" do
        expect(subject).to be_nil
      end

      it "logs the error" do
        subject
        expect(out_stream.string).to include \
          "Unable to read '#{no_permission_file}' to determine cgroup",
          "Permission denied"
      end
    end
  end
end
