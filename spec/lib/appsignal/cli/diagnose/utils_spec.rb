require "appsignal/cli/diagnose/utils"

describe Appsignal::CLI::Diagnose::Utils do
  describe ".username_for_uid" do
    subject { described_class.username_for_uid(uid) }

    context "when user with id exists" do
      let(:uid) { 0 }

      it "returns username" do
        is_expected.to be_kind_of(String)
      end
    end

    context "when user with id does not exist" do
      let(:uid) { -1 }

      it "returns nil" do
        is_expected.to be_nil
      end
    end
  end

  describe ".group_for_gid" do
    subject { described_class.group_for_gid(uid) }

    context "when group with id exists" do
      let(:uid) { 0 }

      it "returns group name" do
        is_expected.to be_kind_of(String)
      end
    end

    context "when group with id does not exist" do
      let(:uid) { -3 }

      it "returns nil" do
        is_expected.to be_nil
      end
    end
  end

  describe ".read_file_content" do
    let(:path) { File.join(spec_system_tmp_dir, "test_file.txt") }
    let(:bytes_to_read) { 100 }
    subject { described_class.read_file_content(path, bytes_to_read) }
    before do
      File.write(path, file_contents)
    end

    context "when file is bigger than read size" do
      let(:file_contents) do
        "".tap do |s|
          100.times do |i|
            s << "line #{i}\n"
          end
        end
      end

      it "returns the last X bytes" do
        is_expected
          .to eq(file_contents[(file_contents.length - bytes_to_read)..file_contents.length])
      end
    end

    context "when file is smaller than read size" do
      let(:file_contents) { "line 1\n" }

      it "returns the whole file content" do
        is_expected.to eq(file_contents)
      end
    end

    context "when reading the file raises an illegal seek error" do
      let(:file_contents) { "line 1\n" }
      before do
        expect(File).to receive(:binread).and_raise(Errno::ESPIPE)
      end

      it "returns the error as the content" do
        expect { subject }.to raise_error(Errno::ESPIPE)
      end
    end
  end
end
