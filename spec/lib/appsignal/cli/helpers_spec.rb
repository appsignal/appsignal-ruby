require "appsignal/cli/helpers"

describe Appsignal::CLI::Helpers do
  include CLIHelpers

  let(:out_stream) { std_stream }
  let(:output) { out_stream.read }
  let(:cli) do
    Class.new do
      extend Appsignal::CLI::Helpers
    end
  end
  before do
    # Speed up tests
    allow(cli).to receive(:sleep)
  end
  around do |example|
    original_stdin = $stdin
    $stdin = StringIO.new
    example.run
    $stdin = original_stdin
  end

  describe ".colorize" do
    subject { cli.send(:colorize, "text", :green) }

    context "when on windows" do
      before { allow(Gem).to receive(:win_platform?).and_return(true) }

      it "outputs plain string" do
        expect(subject).to eq "text"
      end
    end

    context "when coloring is set to false" do
      before { cli.send(:coloring=, false) }

      it "outputs plain string" do
        expect(subject).to eq "text"
      end
    end

    context "when not on windows" do
      before { allow(Gem).to receive(:win_platform?).and_return(false) }

      it "wraps text in color tags" do
        expect(subject).to have_colorized_text(:green, "text")
      end
    end
  end

  describe ".periods" do
    it "prints three periods" do
      capture_stdout(out_stream) { cli.send :periods }
      expect(output).to include("...")
    end
  end

  describe ".press_any_key" do
    before do
      add_cli_input "a" # a as in any
      prepare_cli_input
    end

    it "continues after press" do
      capture_stdout(out_stream) { cli.send :press_any_key }
      expect(output).to include("Press any key")
    end
  end

  describe ".ask_for_input" do
    it "returns the input" do
      add_cli_input "foo"
      prepare_cli_input
      expect(cli.send(:ask_for_input)).to eq("foo")
    end

    context "with input ending with a line break" do
      it "returns only the input" do
        add_cli_input "foo\n"
        prepare_cli_input
        expect(cli.send(:ask_for_input)).to eq("foo")
      end
    end

    context "when user interrupts the program" do
      before do
        expect(cli).to receive(:stdin).and_raise(Interrupt)
        expect(cli).to receive(:exit).with(1)
        capture_stdout(out_stream) { cli.send :ask_for_input }
      end

      it "exits the process" do
        expect(output).to include("Exiting...")
      end
    end
  end

  describe ".yes_or_no" do
    def yes_or_no
      capture_stdout(out_stream) { cli.send(:yes_or_no, "yes or no?: ") }
    end

    it "takes 'y' for an answer" do
      add_cli_input ""
      add_cli_input "nonsense"
      add_cli_input "y"
      prepare_cli_input

      expect(yes_or_no).to be_truthy
    end

    it "takes 'Y' for an answer" do
      add_cli_input "Y"
      prepare_cli_input

      expect(yes_or_no).to be_truthy
    end

    it "takes 'yes' for an answer" do
      add_cli_input "yes"
      prepare_cli_input

      expect(yes_or_no).to be_truthy
    end

    it "takes 'n' for an answer" do
      add_cli_input ""
      add_cli_input "nonsense"
      add_cli_input "n"
      prepare_cli_input

      expect(yes_or_no).to be_falsy
    end

    it "takes 'N' for an answer" do
      add_cli_input "N"
      prepare_cli_input

      expect(yes_or_no).to be_falsy
    end

    it "takes 'no' for an answer" do
      add_cli_input "no"
      prepare_cli_input

      expect(yes_or_no).to be_falsy
    end

    context "with a default" do
      def yes_or_no
        capture_stdout(out_stream) do
          cli.send(:yes_or_no, "yes or no?: ", :default => "y")
        end
      end

      it "returns the default if no input is received from the user" do
        add_cli_input ""
        prepare_cli_input

        expect(yes_or_no).to be_truthy
      end
    end
  end

  describe ".required_input" do
    def required_input
      capture_stdout(out_stream) { cli.send(:required_input, "provide: ") }
    end

    it "collects required input" do
      add_cli_input ""
      add_cli_input "value"
      prepare_cli_input

      expect(required_input).to eq("value")
    end
  end
end
