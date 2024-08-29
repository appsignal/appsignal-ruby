describe Appsignal::Hooks::AtExit do
  describe ".install" do
    before { start_agent(:options => options) }

    context "with :enable_at_exit_reporter == true" do
      let(:options) { { :enable_at_exit_reporter => true } }

      it "installs the at_exit hook" do
        expect(Appsignal::Hooks::AtExit::AtExitCallback).to receive(:call)

        expect(Kernel).to receive(:at_exit).with(no_args) do |*_args, &block|
          block.call
        end

        described_class.new.install
      end
    end

    context "with :enable_at_exit_reporter == false" do
      let(:options) { { :enable_at_exit_reporter => false } }

      it "doesn't install the at_exit hook" do
        expect(Kernel).to_not receive(:at_exit)
      end
    end
  end
end

describe Appsignal::Hooks::AtExit::AtExitCallback do
  around { |example| keep_transactions { example.run } }
  before { start_agent(:options => { :enable_at_exit_reporter => true }) }

  def with_error(error_class, error_message)
    raise error_class, error_message
  rescue error_class => error
    yield error
  end

  def call_callback
    Appsignal::Hooks::AtExit::AtExitCallback.call
  end

  it "reports an error if there's an unhandled error" do
    expect do
      with_error(ExampleException, "error message") do
        call_callback
      end
    end.to change { created_transactions.count }.by(1)

    transaction = last_transaction
    expect(transaction).to have_namespace("unhandled")
    expect(transaction).to have_error("ExampleException", "error message")
  end

  it "calls Appsignal.stop" do
    expect(Appsignal).to receive(:stop).with("at_exit")
    with_error(ExampleException, "error message") do
      call_callback
    end
  end

  it "doesn't report the error if it is also the last error reported" do
    with_error(ExampleException, "error message") do |error|
      Appsignal.report_error(error)
      expect(created_transactions.count).to eq(1)

      expect do
        call_callback
      end.to_not change { created_transactions.count }.from(1)
    end
  end

  it "doesn't report the error if it is a SystemExit exception" do
    with_error(SystemExit, "error message") do |error|
      Appsignal.report_error(error)
      expect(created_transactions.count).to eq(1)

      expect do
        call_callback
      end.to_not change { created_transactions.count }.from(1)
    end
  end

  it "doesn't report the error if it is a SignalException exception" do
    with_error(SignalException, "TERM") do |error|
      Appsignal.report_error(error)
      expect(created_transactions.count).to eq(1)

      expect do
        call_callback
      end.to_not change { created_transactions.count }.from(1)
    end
  end
end
