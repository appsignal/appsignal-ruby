describe Appsignal::CheckIn::Scheduler do
  include WaitForHelper
  include TakeAtMostHelper

  let(:log_stream) { std_stream }
  let(:logs) { log_contents(log_stream) }
  let(:appsignal_options) { {} }
  let(:transmitter) { Appsignal::Transmitter.new("http://checkin-endpoint.invalid") }

  before do
    start_agent(:options => appsignal_options, :internal_logger => test_logger(log_stream))
    allow(transmitter).to receive(:transmit).and_return(Net::HTTPSuccess.new("1.1", 200, "OK"))
    allow(Appsignal::CheckIn).to receive(:transmitter).and_return(transmitter)
    allow(Appsignal::CheckIn).to receive(:scheduler).and_return(subject)
    # Shorten debounce intervals to make the tests run faster.
    stub_const("Appsignal::CheckIn::Scheduler::INITIAL_DEBOUNCE_SECONDS", 0.1)
    stub_const("Appsignal::CheckIn::Scheduler::BETWEEN_TRANSMISSIONS_DEBOUNCE_SECONDS", 0.1)
  end

  after do
    subject.stop
  end

  describe "when no event is sent" do
    it "does not start a thread" do
      expect(subject.thread).to be_nil
    end

    it "does not schedule a debounce" do
      expect(subject.waker).to be_nil
    end

    it "can be stopped" do
      # Set all debounce intervals to 10 seconds, to make the assertion
      # fail if it waits for the debounce -- this ensures that what is being
      # tested is that no debounces are awaited when stopping the scheduler.
      stub_const("Appsignal::CheckIn::Scheduler::INITIAL_DEBOUNCE_SECONDS", 10)
      stub_const("Appsignal::CheckIn::Scheduler::BETWEEN_TRANSMISSIONS_DEBOUNCE_SECONDS", 10)

      take_at_most(0.1) do
        expect { subject.stop }.not_to raise_error
      end
    end

    it "can be stopped more than once" do
      # Set all debounce intervals to 10 seconds, to make the assertion
      # fail if it waits for the debounce -- this ensures that what is being
      # tested is that no debounces are awaited when stopping the scheduler.
      stub_const("Appsignal::CheckIn::Scheduler::INITIAL_DEBOUNCE_SECONDS", 10)
      stub_const("Appsignal::CheckIn::Scheduler::BETWEEN_TRANSMISSIONS_DEBOUNCE_SECONDS", 10)

      take_at_most(0.1) do
        expect { subject.stop }.not_to raise_error
        expect { subject.stop }.not_to raise_error
      end
    end

    it "closes the queue when stopped" do
      subject.stop
      expect(subject.queue.closed?).to be(true)
    end
  end

  describe "when an event is sent" do
    it "starts a thread" do
      Appsignal::CheckIn.cron("test")
      expect(subject.thread).to be_a(Thread)
    end

    it "schedules a debounce" do
      Appsignal::CheckIn.cron("test")
      expect(subject.waker).to be_a(Thread)
    end

    it "schedules the event to be transmitted" do
      expect(transmitter).to receive(:transmit).with([hash_including(
        :identifier => "test",
        :check_in_type => "cron",
        :kind => "finish"
      )], :format => :ndjson)

      expect(subject.events).to be_empty

      Appsignal::CheckIn.cron("test")

      expect(subject.events).not_to be_empty

      wait_for("the event to be transmitted") { subject.transmitted == 1 }

      expect(subject.events).to be_empty

      expect(logs).to contains_log(:debug, "Scheduling cron check-in `test` finish event")
      expect(logs).to contains_log(:debug, "Transmitted cron check-in `test` finish event")
    end

    it "waits for the event to be transmitted when stopped" do
      # Set all debounce intervals to 10 seconds, to make the test
      # fail if it waits for the debounce -- this ensures that what is being
      # tested is that the events are transmitted immediately when the
      # scheduler is stopped, without waiting for any debounce.
      stub_const("Appsignal::CheckIn::Scheduler::INITIAL_DEBOUNCE_SECONDS", 10)
      stub_const("Appsignal::CheckIn::Scheduler::BETWEEN_TRANSMISSIONS_DEBOUNCE_SECONDS", 10)

      expect(transmitter).to receive(:transmit).with([hash_including(
        :identifier => "test",
        :check_in_type => "cron",
        :kind => "finish"
      )], :format => :ndjson)

      Appsignal::CheckIn.cron("test")

      expect(subject.events).not_to be_empty

      take_at_most(0.1) do
        expect { subject.stop }.not_to raise_error
      end

      # Check that the thread wasn't killed before the transmission was
      # completed.
      expect(subject.transmitted).to eq(1)

      expect(subject.events).to be_empty

      expect(logs).to contains_log(:debug, "Scheduling cron check-in `test` finish event")
      expect(logs).to contains_log(:debug, "Transmitted cron check-in `test` finish event")
    end

    it "can be stopped more than once" do
      # Set all debounce intervals to 10 seconds, to make the test
      # fail if it waits for the debounce -- this ensures that what is being
      # tested is that the events are transmitted immediately when the
      # scheduler is stopped, without waiting for the debounce interval.
      stub_const("Appsignal::CheckIn::Scheduler::INITIAL_DEBOUNCE_SECONDS", 10)
      stub_const("Appsignal::CheckIn::Scheduler::BETWEEN_TRANSMISSIONS_DEBOUNCE_SECONDS", 10)

      Appsignal::CheckIn.cron("test")
      take_at_most(0.1) do
        expect { subject.stop }.not_to raise_error
      end

      # Check that the thread wasn't killed before the transmission was
      # completed.
      expect(subject.transmitted).to eq(1)

      take_at_most(0.1) do
        expect { subject.stop }.not_to raise_error
      end
    end

    it "closes the queue when stopped" do
      Appsignal::CheckIn.cron("test")
      subject.stop
      expect(subject.queue.closed?).to be(true)
    end

    it "kills the thread when stopped" do
      Appsignal::CheckIn.cron("test")
      subject.stop
      expect(subject.thread.alive?).to be(false)
    end

    it "unschedules the debounce when stopped" do
      Appsignal::CheckIn.cron("test")
      waker = subject.waker
      subject.stop
      expect(waker.alive?).to be(false)
      expect(subject.waker).to be_nil
    end
  end

  describe "when many events are sent" do
    describe "within the short debounce interval" do
      it "transmits all events at once" do
        expect(transmitter).to receive(:transmit).with(
          ["first", "second", "third"].map do |identifier|
            hash_including(
              :identifier => identifier,
              :check_in_type => "cron",
              :kind => "finish"
            )
          end, :format => :ndjson
        )

        Appsignal::CheckIn.cron("first")
        Appsignal::CheckIn.cron("second")
        Appsignal::CheckIn.cron("third")

        wait_for("the events to be transmitted") { subject.transmitted == 1 }
      end

      it "transmits all events at once when stopped" do
        # Set a short debounce interval of 10 seconds, to make the final wait
        # fail if it waits for the debounce -- this ensures that what is being
        # tested is that the events are transmitted when the scheduler is
        # stopped.
        stub_const("Appsignal::CheckIn::Scheduler::INITIAL_DEBOUNCE_SECONDS", 10)

        expect(transmitter).to receive(:transmit).with(
          ["first", "second", "third"].map do |identifier|
            hash_including(
              :identifier => identifier,
              :check_in_type => "cron",
              :kind => "finish"
            )
          end, :format => :ndjson
        )

        Appsignal::CheckIn.cron("first")
        Appsignal::CheckIn.cron("second")
        Appsignal::CheckIn.cron("third")

        subject.stop

        wait_for("the events to be transmitted") { subject.transmitted == 1 }
      end
    end

    describe "further apart than the short debounce interval" do
      it "transmits the first event and enqueues future events" do
        expect(transmitter).to receive(:transmit).with([hash_including(
          :identifier => "first",
          :check_in_type => "cron",
          :kind => "finish"
        )], :format => :ndjson)

        Appsignal::CheckIn.cron("first")

        wait_for("the first event to be transmitted") { subject.transmitted == 1 }

        Appsignal::CheckIn.cron("second")
        Appsignal::CheckIn.cron("third")

        expect(subject.events).to match(["second", "third"].map do |identifier|
          hash_including({
            :identifier => identifier,
            :check_in_type => "cron",
            :kind => "finish"
          })
        end)
      end

      it "transmits the other events after the debounce interval" do
        expect(transmitter).to receive(:transmit)

        Appsignal::CheckIn.cron("first")

        wait_for("the first event to be transmitted") { subject.transmitted == 1 }

        expect(transmitter).to receive(:transmit).with(
          ["second", "third"].map do |identifier|
            hash_including(
              :identifier => identifier,
              :check_in_type => "cron",
              :kind => "finish"
            )
          end, :format => :ndjson
        )

        Appsignal::CheckIn.cron("second")
        Appsignal::CheckIn.cron("third")

        expect(subject.events).to_not be_empty

        wait_for("the other events to be transmitted") { subject.transmitted == 2 }

        expect(subject.events).to be_empty

        expect(logs).to contains_log(:debug, "Scheduling cron check-in `first` finish event")
        expect(logs).to contains_log(:debug, "Transmitted cron check-in `first` finish event")
        expect(logs).to contains_log(:debug, "Scheduling cron check-in `second` finish event")
        expect(logs).to contains_log(:debug, "Scheduling cron check-in `third` finish event")
        expect(logs).to contains_log(:debug, "Transmitted 2 check-in events")
      end

      it "transmits the other events when stopped" do
        # Restore the original long debounce interval of 10 seconds, to make
        # the final wait fail if it waits for the debounce -- this ensures
        # that what is being tested is that the events are transmitted
        # immediately when the scheduler is stopped.
        stub_const("Appsignal::CheckIn::Scheduler::BETWEEN_TRANSMISSIONS_DEBOUNCE_SECONDS", 10)

        expect(transmitter).to receive(:transmit)

        Appsignal::CheckIn.cron("first")

        wait_for("the event to be transmitted") { subject.transmitted == 1 }

        expect(transmitter).to receive(:transmit).with(
          ["second", "third"].map do |identifier|
            hash_including(
              :identifier => identifier,
              :check_in_type => "cron",
              :kind => "finish"
            )
          end, :format => :ndjson
        )

        Appsignal::CheckIn.cron("second")
        Appsignal::CheckIn.cron("third")

        expect(subject.events).to_not be_empty

        subject.stop

        wait_for("the other events to be transmitted") { subject.transmitted == 2 }

        expect(subject.events).to be_empty

        expect(logs).to contains_log(:debug, "Scheduling cron check-in `first` finish event")
        expect(logs).to contains_log(:debug, "Transmitted cron check-in `first` finish event")
        expect(logs).to contains_log(:debug, "Scheduling cron check-in `second` finish event")
        expect(logs).to contains_log(:debug, "Scheduling cron check-in `third` finish event")
        expect(logs).to contains_log(:debug, "Transmitted 2 check-in events")
      end
    end
  end

  describe "when a similar event is sent more than once" do
    it "only transmits one of the similar events" do
      # We must instantiate `Appsignal::CheckIn::Cron` directly, as the
      # `.cron` helper would use a different digest for each invocation.
      cron = Appsignal::CheckIn::Cron.new(:identifier => "test")

      expect(transmitter).to receive(:transmit).with([hash_including(
        :identifier => "test",
        :check_in_type => "cron",
        :kind => "start"
      )], :format => :ndjson)

      cron.start
      cron.start

      wait_for("the event to be transmitted") { subject.transmitted == 1 }

      expect(logs).to contains_log(
        :debug,
        "Scheduling cron check-in `test` start event (digest #{cron.digest}) to be transmitted"
      )
      expect(logs).to contains_log(
        :debug,
        "Scheduling cron check-in `test` start event (digest #{cron.digest}) to be transmitted"
      )
      expect(logs).to contains_log(
        :debug,
        "Replacing previously scheduled cron check-in `test` start event (digest #{cron.digest})"
      )
      expect(logs).to contains_log(
        :debug,
        "Transmitted cron check-in `test` start event (digest #{cron.digest})"
      )
    end
  end

  describe "when the scheduler is stopped" do
    it "does not schedule any events to be transmitted" do
      expect(transmitter).not_to receive(:transmit)

      subject.stop

      Appsignal::CheckIn.cron("test")

      expect(subject.events).to be_empty

      expect(logs).to contains_log(
        :debug,
        /Cannot transmit cron check-in `test` finish event .+: AppSignal is stopped/
      )
    end
  end

  describe "when AppSignal is not active" do
    let(:appsignal_options) { { :active => false } }

    it "does not schedule any events to be transmitted" do
      subject.stop

      Appsignal::CheckIn.cron("test")

      expect(subject.events).to be_empty

      expect(logs).to contains_log(
        :debug,
        /Cannot transmit cron check-in `test` finish event .+: AppSignal is not active/
      )
    end
  end

  describe "when transmitting returns a non-success response code" do
    it "logs the error and continues" do
      expect(transmitter).to receive(:transmit).and_return(
        Net::HTTPNotFound.new("1.1", 404, "Not Found")
      )

      Appsignal::CheckIn.cron("first")

      wait_for("the first event to be transmitted") { subject.transmitted == 1 }

      expect(transmitter).to receive(:transmit).and_return(
        Net::HTTPSuccess.new("1.1", 200, "OK")
      )

      Appsignal::CheckIn.cron("second")

      wait_for("the second event to be transmitted") { subject.transmitted == 2 }

      expect(logs).to contains_log(
        :error,
        /Failed to transmit cron check-in `first` finish event .+: 404 status code/
      )
      expect(logs).to contains_log(
        :debug,
        "Transmitted cron check-in `second` finish event"
      )
    end
  end

  describe "when transmitting throws an error" do
    it "logs the error and continues" do
      expect(transmitter).to receive(:transmit).and_raise("Something went wrong")

      Appsignal::CheckIn.cron("first")

      wait_for("the first event to be transmitted") { subject.transmitted == 1 }

      expect(transmitter).to receive(:transmit).and_return(
        Net::HTTPSuccess.new("1.1", 200, "OK")
      )

      Appsignal::CheckIn.cron("second")

      wait_for("the second event to be transmitted") { subject.transmitted == 2 }

      expect(logs).to contains_log(
        :error,
        /Failed to transmit cron check-in `first` finish event .+: Something went wrong/
      )
      expect(logs).to contains_log(
        :debug,
        "Transmitted cron check-in `second` finish event"
      )
    end
  end
end
