require "appsignal/cli/diagnose/utils"

describe Appsignal::CLI::Diagnose::Utils do
  describe ".read_file_content" do
    let(:path) { File.join(spec_system_tmp_dir, "test_file.txt") }
    let(:bytes_to_read) { 100 }
    subject { described_class.read_file_content(path, bytes_to_read) }
    before do
      File.open path, "w+" do |f|
        f.write file_contents
      end
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
  end
end
