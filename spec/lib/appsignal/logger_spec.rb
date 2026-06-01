shared_examples "tagged logging" do
  describe "with tags from logger.tagged" do
    it "in agent mode", :agent_mode do
      expect(Appsignal::Extension).to receive(:log)
        .with(
          "group",
          3,
          3,
          "[My tag] [My other tag] Some message\n",
          Appsignal::Utils::Data.generate({})
        )

      logger.tagged("My tag", "My other tag") do
        logger.info("Some message")
      end
    end

    it "in collector mode", :collector_mode do
      expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
        .with(
          "group",
          ::Logger::INFO,
          Appsignal::Logger::AUTODETECT,
          "[My tag] [My other tag] Some message\n",
          {}
        )

      logger.tagged("My tag", "My other tag") do
        logger.info("Some message")
      end
    end
  end

  describe "with nested tags from logger.tagged" do
    it "in agent mode", :agent_mode do
      expect(Appsignal::Extension).to receive(:log)
        .with(
          "group",
          3,
          3,
          "[My tag] [My other tag] [Nested tag] [Nested other tag] Some message\n",
          Appsignal::Utils::Data.generate({})
        )

      logger.tagged("My tag", "My other tag") do
        logger.tagged("Nested tag", "Nested other tag") do
          logger.info("Some message")
        end
      end
    end

    it "in collector mode", :collector_mode do
      expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
        .with(
          "group",
          ::Logger::INFO,
          Appsignal::Logger::AUTODETECT,
          "[My tag] [My other tag] [Nested tag] [Nested other tag] Some message\n",
          {}
        )

      logger.tagged("My tag", "My other tag") do
        logger.tagged("Nested tag", "Nested other tag") do
          logger.info("Some message")
        end
      end
    end
  end

  describe "with tags from Rails.application.config.log_tags" do
    it "in agent mode", :agent_mode do
      allow(Appsignal::Extension).to receive(:log)

      logger.push_tags(["Request tag", "Second tag"])
      logger.tagged("First message", "My other tag") { logger.info("Some message") }
      expect(Appsignal::Extension).to have_received(:log)
        .with(
          "group",
          3,
          3,
          "[Request tag] [Second tag] [First message] [My other tag] Some message\n",
          Appsignal::Utils::Data.generate({})
        )

      logger.tagged("Second message") { logger.info("Some message") }
      expect(Appsignal::Extension).to have_received(:log)
        .with(
          "group",
          3,
          3,
          "[Request tag] [Second tag] [Second message] Some message\n",
          Appsignal::Utils::Data.generate({})
        )

      logger.pop_tags(2)
      logger.tagged("Third message") { logger.info("Some message") }
      expect(Appsignal::Extension).to have_received(:log)
        .with(
          "group",
          3,
          3,
          "[Third message] Some message\n",
          Appsignal::Utils::Data.generate({})
        )
    end

    it "in collector mode", :collector_mode do
      allow(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)

      logger.push_tags(["Request tag", "Second tag"])
      logger.tagged("First message", "My other tag") { logger.info("Some message") }
      expect(Appsignal::Logger::OpenTelemetryBackend).to have_received(:emit)
        .with(
          "group",
          ::Logger::INFO,
          Appsignal::Logger::AUTODETECT,
          "[Request tag] [Second tag] [First message] [My other tag] Some message\n",
          {}
        )

      logger.tagged("Second message") { logger.info("Some message") }
      expect(Appsignal::Logger::OpenTelemetryBackend).to have_received(:emit)
        .with(
          "group",
          ::Logger::INFO,
          Appsignal::Logger::AUTODETECT,
          "[Request tag] [Second tag] [Second message] Some message\n",
          {}
        )

      logger.pop_tags(2)
      logger.tagged("Third message") { logger.info("Some message") }
      expect(Appsignal::Logger::OpenTelemetryBackend).to have_received(:emit)
        .with(
          "group",
          ::Logger::INFO,
          Appsignal::Logger::AUTODETECT,
          "[Third message] Some message\n",
          {}
        )
    end
  end

  describe "with tags from Rails 8 application.config.log_tags" do
    it "in agent mode", :agent_mode do
      allow(Appsignal::Extension).to receive(:log)

      logger.push_tags("Request tag", "Second tag")
      logger.tagged("First message", "My other tag") { logger.info("Some message") }
      expect(Appsignal::Extension).to have_received(:log)
        .with(
          "group",
          3,
          3,
          "[Request tag] [Second tag] [First message] [My other tag] Some message\n",
          Appsignal::Utils::Data.generate({})
        )
    end

    it "in collector mode", :collector_mode do
      allow(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)

      logger.push_tags("Request tag", "Second tag")
      logger.tagged("First message", "My other tag") { logger.info("Some message") }
      expect(Appsignal::Logger::OpenTelemetryBackend).to have_received(:emit)
        .with(
          "group",
          ::Logger::INFO,
          Appsignal::Logger::AUTODETECT,
          "[Request tag] [Second tag] [First message] [My other tag] Some message\n",
          {}
        )
    end
  end

  describe "clearing all tags with clear_tags!" do
    it "in agent mode", :agent_mode do
      allow(Appsignal::Extension).to receive(:log)

      logger.push_tags(["Request tag", "Second tag"])
      logger.tagged("First message", "My other tag") { logger.info("Some message") }
      expect(Appsignal::Extension).to have_received(:log)
        .with(
          "group",
          3,
          3,
          "[Request tag] [Second tag] [First message] [My other tag] Some message\n",
          Appsignal::Utils::Data.generate({})
        )

      logger.clear_tags!
      logger.tagged("First message", "My other tag") { logger.info("Some message") }
      expect(Appsignal::Extension).to have_received(:log)
        .with(
          "group",
          3,
          3,
          "[First message] [My other tag] Some message\n",
          Appsignal::Utils::Data.generate({})
        )
    end

    it "in collector mode", :collector_mode do
      allow(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)

      logger.push_tags(["Request tag", "Second tag"])
      logger.tagged("First message", "My other tag") { logger.info("Some message") }
      expect(Appsignal::Logger::OpenTelemetryBackend).to have_received(:emit)
        .with(
          "group",
          ::Logger::INFO,
          Appsignal::Logger::AUTODETECT,
          "[Request tag] [Second tag] [First message] [My other tag] Some message\n",
          {}
        )

      logger.clear_tags!
      logger.tagged("First message", "My other tag") { logger.info("Some message") }
      expect(Appsignal::Logger::OpenTelemetryBackend).to have_received(:emit)
        .with(
          "group",
          ::Logger::INFO,
          Appsignal::Logger::AUTODETECT,
          "[First message] [My other tag] Some message\n",
          {}
        )
    end
  end

  describe "with tags passed as an array" do
    it "in agent mode", :agent_mode do
      expect(Appsignal::Extension).to receive(:log)
        .with(
          "group",
          3,
          3,
          "[My tag] [My other tag] Some message\n",
          Appsignal::Utils::Data.generate({})
        )

      logger.tagged(["My tag", "My other tag"]) do
        logger.info("Some message")
      end
    end

    it "in collector mode", :collector_mode do
      expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
        .with(
          "group",
          ::Logger::INFO,
          Appsignal::Logger::AUTODETECT,
          "[My tag] [My other tag] Some message\n",
          {}
        )

      logger.tagged(["My tag", "My other tag"]) do
        logger.info("Some message")
      end
    end
  end

  # Calling `#tagged` without a block is not supported by
  # `ActiveSupport::TaggedLogging` in Rails 6 and earlier. Only run this
  # in builds where Rails is not present, or builds where Rails 7 or later
  # is present.
  if !DependencyHelper.rails_present? || DependencyHelper.rails7_present?
    describe "when calling #tagged without a block" do
      describe "returns a new logger with the tags added" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Extension).to receive(:log)
            .with(
              "group",
              3,
              3,
              "[My tag] [My other tag] Some message\n",
              Appsignal::Utils::Data.generate({})
            )

          logger.tagged("My tag", "My other tag").info("Some message")
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
            .with(
              "group",
              ::Logger::INFO,
              Appsignal::Logger::AUTODETECT,
              "[My tag] [My other tag] Some message\n",
              {}
            )

          logger.tagged("My tag", "My other tag").info("Some message")
        end
      end

      describe "does not modify the original logger" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Extension).to receive(:log)
            .with(
              "group",
              3,
              3,
              "[My tag] [My other tag] Some message\n",
              Appsignal::Utils::Data.generate({})
            )

          new_logger = logger.tagged("My tag", "My other tag")
          new_logger.info("Some message")

          expect(Appsignal::Extension).to receive(:log)
            .with(
              "group",
              3,
              3,
              "Some message\n",
              Appsignal::Utils::Data.generate({})
            )

          logger.info("Some message")
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
            .with(
              "group",
              ::Logger::INFO,
              Appsignal::Logger::AUTODETECT,
              "[My tag] [My other tag] Some message\n",
              {}
            )

          new_logger = logger.tagged("My tag", "My other tag")
          new_logger.info("Some message")

          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
            .with(
              "group",
              ::Logger::INFO,
              Appsignal::Logger::AUTODETECT,
              "Some message\n",
              {}
            )

          logger.info("Some message")
        end
      end

      describe "can be chained" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Extension).to receive(:log)
            .with(
              "group",
              3,
              3,
              "[My tag] [My other tag] [My third tag] Some message\n",
              Appsignal::Utils::Data.generate({})
            )

          logger.tagged("My tag", "My other tag").tagged("My third tag").info("Some message")
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
            .with(
              "group",
              ::Logger::INFO,
              Appsignal::Logger::AUTODETECT,
              "[My tag] [My other tag] [My third tag] Some message\n",
              {}
            )

          logger.tagged("My tag", "My other tag").tagged("My third tag").info("Some message")
        end
      end

      describe "can be chained before a block invocation" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Extension).to receive(:log)
            .with(
              "group",
              3,
              3,
              "[My tag] [My other tag] [My third tag] Some message\n",
              Appsignal::Utils::Data.generate({})
            )

          # Use the logger passed to the block: the logger returned from
          # the first #tagged invocation is a new instance.
          logger.tagged("My tag", "My other tag").tagged("My third tag") do |logger|
            logger.info("Some message")
          end
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
            .with(
              "group",
              ::Logger::INFO,
              Appsignal::Logger::AUTODETECT,
              "[My tag] [My other tag] [My third tag] Some message\n",
              {}
            )

          logger.tagged("My tag", "My other tag").tagged("My third tag") do |logger|
            logger.info("Some message")
          end
        end
      end

      describe "can be chained after a block invocation" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Extension).to receive(:log)
            .with(
              "group",
              3,
              3,
              "[My tag] [My other tag] [My third tag] Some message\n",
              Appsignal::Utils::Data.generate({})
            )

          logger.tagged("My tag", "My other tag") do
            logger.tagged("My third tag").info("Some message")
          end
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
            .with(
              "group",
              ::Logger::INFO,
              Appsignal::Logger::AUTODETECT,
              "[My tag] [My other tag] [My third tag] Some message\n",
              {}
            )

          logger.tagged("My tag", "My other tag") do
            logger.tagged("My third tag").info("Some message")
          end
        end
      end
    end
  end
end

describe Appsignal::Logger do
  let(:log_stream) { StringIO.new }
  let(:logs) { log_contents(log_stream) }
  let(:logger) { Appsignal::Logger.new("group", :level => ::Logger::DEBUG) }

  before do
    Appsignal.internal_logger = test_logger(log_stream)
  end

  it "should not create a logger with a nil group" do
    expect do
      Appsignal::Logger.new(nil)
    end.to raise_error(TypeError)
  end

  describe "format validation" do
    it "accepts the documented format constants" do
      [
        Appsignal::Logger::PLAINTEXT,
        Appsignal::Logger::LOGFMT,
        Appsignal::Logger::JSON,
        Appsignal::Logger::AUTODETECT
      ].each do |format|
        expect(Appsignal.internal_logger).not_to receive(:warn)
        logger = Appsignal::Logger.new("group", :format => format)
        expect(logger.instance_variable_get(:@format)).to eq(format)
      end
    end

    it "warns and falls back to AUTODETECT for an unknown format" do
      expect(Appsignal.internal_logger).to receive(:warn)
        .with(/Unknown Appsignal::Logger format 99; falling back to AUTODETECT/)

      logger = Appsignal::Logger.new("group", :format => 99)
      expect(logger.instance_variable_get(:@format)).to eq(Appsignal::Logger::AUTODETECT)
    end
  end

  describe "#add" do
    describe "with a level and message" do
      it "in agent mode", :agent_mode do
        expect(Appsignal::Extension).to receive(:log)
          .with("group", 3, 3, "Log message", instance_of(Appsignal::Extension::Data))
        logger.add(::Logger::INFO, "Log message")
      end

      it "in collector mode", :collector_mode do
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("group", ::Logger::INFO, Appsignal::Logger::AUTODETECT, "Log message", {})
        logger.add(::Logger::INFO, "Log message")
      end
    end

    describe "with a non-string message" do
      it "in agent mode", :agent_mode do
        expect(Appsignal::Extension).to receive(:log)
          .with("group", 3, 3, "123", instance_of(Appsignal::Extension::Data))
        expect(Appsignal::Extension).to receive(:log)
          .with("group", 3, 3, "{}", instance_of(Appsignal::Extension::Data))
        expect(Appsignal::Extension).to receive(:log)
          .with("group", 3, 3, "[]", instance_of(Appsignal::Extension::Data))
        logger.add(::Logger::INFO, 123)
        logger.add(::Logger::INFO, {})
        logger.add(::Logger::INFO, [])
      end

      it "in collector mode", :collector_mode do
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("group", ::Logger::INFO, Appsignal::Logger::AUTODETECT, "123", {})
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("group", ::Logger::INFO, Appsignal::Logger::AUTODETECT, "{}", {})
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("group", ::Logger::INFO, Appsignal::Logger::AUTODETECT, "[]", {})
        logger.add(::Logger::INFO, 123)
        logger.add(::Logger::INFO, {})
        logger.add(::Logger::INFO, [])
      end
    end

    describe "with a block" do
      it "in agent mode", :agent_mode do
        expect(Appsignal::Extension).to receive(:log)
          .with("group", 3, 3, "Log message", instance_of(Appsignal::Extension::Data))
        logger.add(::Logger::INFO) { "Log message" }
      end

      it "in collector mode", :collector_mode do
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("group", ::Logger::INFO, Appsignal::Logger::AUTODETECT, "Log message", {})
        logger.add(::Logger::INFO) { "Log message" }
      end
    end

    describe "with a level, message and group" do
      it "in agent mode", :agent_mode do
        expect(Appsignal::Extension).to receive(:log)
          .with("other_group", 3, 3, "Log message", instance_of(Appsignal::Extension::Data))
        logger.add(::Logger::INFO, "Log message", "other_group")
      end

      it "in collector mode", :collector_mode do
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("other_group", ::Logger::INFO, Appsignal::Logger::AUTODETECT, "Log message", {})
        logger.add(::Logger::INFO, "Log message", "other_group")
      end
    end

    describe "with info log level" do
      let(:logger) { Appsignal::Logger.new("group", :level => ::Logger::INFO) }

      describe "when the call's level is too low" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Extension).not_to receive(:log)
          logger.add(::Logger::DEBUG, "Log message")
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).not_to receive(:emit)
          logger.add(::Logger::DEBUG, "Log message")
        end
      end
    end

    describe "with the PLAINTEXT format set" do
      let(:logger) { Appsignal::Logger.new("group", :format => Appsignal::Logger::PLAINTEXT) }

      it "in agent mode", :agent_mode do
        expect(Appsignal::Extension).to receive(:log)
          .with("group", 3, 0, "Log message", instance_of(Appsignal::Extension::Data))
        logger.add(::Logger::INFO, "Log message")
      end

      it "in collector mode", :collector_mode do
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("group", ::Logger::INFO, Appsignal::Logger::PLAINTEXT, "Log message", {})
        logger.add(::Logger::INFO, "Log message")
      end
    end

    describe "with the logfmt format set" do
      let(:logger) { Appsignal::Logger.new("group", :format => Appsignal::Logger::LOGFMT) }

      it "in agent mode", :agent_mode do
        expect(Appsignal::Extension).to receive(:log)
          .with("group", 3, 1, "Log message", instance_of(Appsignal::Extension::Data))
        logger.add(::Logger::INFO, "Log message")
      end

      it "in collector mode", :collector_mode do
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("group", ::Logger::INFO, Appsignal::Logger::LOGFMT, "Log message", {})
        logger.add(::Logger::INFO, "Log message")
      end
    end

    describe "with the JSON format set" do
      let(:logger) { Appsignal::Logger.new("group", :format => Appsignal::Logger::JSON) }

      it "in agent mode", :agent_mode do
        expect(Appsignal::Extension).to receive(:log)
          .with("group", 3, 2, "Log message", instance_of(Appsignal::Extension::Data))
        logger.add(::Logger::INFO, "Log message")
      end

      it "in collector mode", :collector_mode do
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("group", ::Logger::INFO, Appsignal::Logger::JSON, "Log message", {})
        logger.add(::Logger::INFO, "Log message")
      end
    end

    describe "with a formatter set" do
      before do
        logger.formatter = proc do |_level, _timestamp, _appname, message|
          "formatted: '#{message}'"
        end
      end

      describe "logs with a level, message and group" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Extension).to receive(:log).with(
            "other_group",
            3,
            3,
            "formatted: 'Log message'",
            instance_of(Appsignal::Extension::Data)
          )
          logger.add(::Logger::INFO, "Log message", "other_group")
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit).with(
            "other_group",
            ::Logger::INFO,
            Appsignal::Logger::AUTODETECT,
            "formatted: 'Log message'",
            {}
          )
          logger.add(::Logger::INFO, "Log message", "other_group")
        end
      end

      describe "calls the formatter with the original message" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Extension).to receive(:log)
            .with(
              "group",
              3,
              3,
              a_string_starting_with("formatted:"),
              instance_of(Appsignal::Extension::Data)
            )
          expect(logger.formatter).to receive(:call)
            .with(::Logger::INFO, instance_of(Time), "group", { :a => "b" })
            .and_call_original
          logger.add(::Logger::INFO, { :a => "b" })
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
            .with(
              "group",
              ::Logger::INFO,
              Appsignal::Logger::AUTODETECT,
              a_string_starting_with("formatted:"),
              {}
            )
          expect(logger.formatter).to receive(:call)
            .with(::Logger::INFO, instance_of(Time), "group", { :a => "b" })
            .and_call_original
          logger.add(::Logger::INFO, { :a => "b" })
        end
      end

      describe "calls #to_s on the formatter output if it is not a string" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Extension).to receive(:log)
            .with("group", 3, 3, "123", instance_of(Appsignal::Extension::Data))
          expect(logger.formatter).to receive(:call)
            .with(::Logger::INFO, instance_of(Time), "group", 123)
            .and_return(123)
          logger.add(::Logger::INFO, 123)
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
            .with("group", ::Logger::INFO, Appsignal::Logger::AUTODETECT, "123", {})
          expect(logger.formatter).to receive(:call)
            .with(::Logger::INFO, instance_of(Time), "group", 123)
            .and_return(123)
          logger.add(::Logger::INFO, 123)
        end
      end
    end
  end

  describe "#silence" do
    describe "calls the given block" do
      it_in_both_modes do
        num = 1
        logger.silence { num += 1 }
        expect(num).to eq(2)
      end
    end

    describe "silences the logger up to, but not including, the given level" do
      it "in agent mode", :agent_mode do
        expect(Appsignal::Extension).not_to receive(:log)
          .with("group", 3, 3, "Log message", instance_of(Appsignal::Extension::Data))
        expect(Appsignal::Extension).to receive(:log)
          .with("group", 5, 3, "Log message", instance_of(Appsignal::Extension::Data))

        logger.silence(::Logger::WARN) do
          logger.info("Log message")
          logger.warn("Log message")
        end
      end

      it "in collector mode", :collector_mode do
        expect(Appsignal::Logger::OpenTelemetryBackend).not_to receive(:emit)
          .with("group", ::Logger::INFO, Appsignal::Logger::AUTODETECT, "Log message", {})
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("group", ::Logger::WARN, Appsignal::Logger::AUTODETECT, "Log message", {})

        logger.silence(::Logger::WARN) do
          logger.info("Log message")
          logger.warn("Log message")
        end
      end
    end

    describe "silences the logger to error level by default" do
      it "in agent mode", :agent_mode do
        [2, 3, 5].each do |severity|
          expect(Appsignal::Extension).not_to receive(:log)
            .with("group", severity, 3, "Log message", instance_of(Appsignal::Extension::Data))
        end
        [6, 7].each do |severity|
          expect(Appsignal::Extension).to receive(:log)
            .with("group", severity, 3, "Log message", instance_of(Appsignal::Extension::Data))
        end

        logger.silence do
          logger.debug("Log message")
          logger.info("Log message")
          logger.warn("Log message")
          logger.error("Log message")
          logger.fatal("Log message")
        end
      end

      it "in collector mode", :collector_mode do
        [::Logger::DEBUG, ::Logger::INFO, ::Logger::WARN].each do |severity|
          expect(Appsignal::Logger::OpenTelemetryBackend).not_to receive(:emit)
            .with("group", severity, Appsignal::Logger::AUTODETECT, "Log message", {})
        end
        [::Logger::ERROR, ::Logger::FATAL].each do |severity|
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
            .with("group", severity, Appsignal::Logger::AUTODETECT, "Log message", {})
        end

        logger.silence do
          logger.debug("Log message")
          logger.info("Log message")
          logger.warn("Log message")
          logger.error("Log message")
          logger.fatal("Log message")
        end
      end
    end
  end

  describe "#broadcast_to" do
    describe "broadcasts the message to the given logger" do
      it "in agent mode", :agent_mode do
        other_device = StringIO.new
        other_logger = ::Logger.new(other_device)
        logger.broadcast_to(other_logger)

        expect(Appsignal::Extension).to receive(:log)
          .with("group", 3, 3, "Log message", instance_of(Appsignal::Extension::Data))

        logger.info("Log message")

        expect(other_device.string).to include("INFO -- group: Log message")
      end

      it "in collector mode", :collector_mode do
        other_device = StringIO.new
        other_logger = ::Logger.new(other_device)
        logger.broadcast_to(other_logger)

        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("group", ::Logger::INFO, Appsignal::Logger::AUTODETECT, "Log message", {})

        logger.info("Log message")

        expect(other_device.string).to include("INFO -- group: Log message")
      end
    end

    describe "broadcasts the message to the given logger when it's below the log level" do
      it "in agent mode", :agent_mode do
        logger = Appsignal::Logger.new("group", :level => ::Logger::INFO)
        other_device = StringIO.new
        other_logger = ::Logger.new(other_device)
        logger.broadcast_to(other_logger)

        expect(Appsignal::Extension).not_to receive(:log)

        logger.debug("Log message")

        expect(other_device.string).to include("DEBUG -- group: Log message")
      end

      it "in collector mode", :collector_mode do
        logger = Appsignal::Logger.new("group", :level => ::Logger::INFO)
        other_device = StringIO.new
        other_logger = ::Logger.new(other_device)
        logger.broadcast_to(other_logger)

        expect(Appsignal::Logger::OpenTelemetryBackend).not_to receive(:emit)

        logger.debug("Log message")

        expect(other_device.string).to include("DEBUG -- group: Log message")
      end
    end

    describe "does not broadcast the message to the given logger when silenced" do
      it "in agent mode", :agent_mode do
        other_device = StringIO.new
        other_logger = ::Logger.new(other_device)
        logger.broadcast_to(other_logger)

        expect(Appsignal::Extension).not_to receive(:log)

        logger.silence { logger.info("Log message") }

        expect(other_device.string).to eq("")
      end

      it "in collector mode", :collector_mode do
        other_device = StringIO.new
        other_logger = ::Logger.new(other_device)
        logger.broadcast_to(other_logger)

        expect(Appsignal::Logger::OpenTelemetryBackend).not_to receive(:emit)

        logger.silence { logger.info("Log message") }

        expect(other_device.string).to eq("")
      end
    end

    context "with a formatter" do
      describe "sets the formatter on broadcasted loggers that support it" do
        it_in_both_modes do
          other_device = StringIO.new
          other_logger = ::Logger.new(other_device)
          logger.broadcast_to(other_logger)

          formatter = proc { |_level, _timestamp, _appname, message| "custom: #{message}" }
          logger.formatter = formatter

          expect(logger.formatter).to eq(formatter)
          expect(other_logger.formatter).to eq(formatter)
        end
      end

      describe "does not raise an error when a broadcasted logger does not support formatter=" do
        it_in_both_modes do
          logger_without_formatter = double("logger without formatter")
          allow(logger_without_formatter).to receive(:respond_to?).with(:formatter=).and_return(false)
          allow(logger_without_formatter).to receive(:add)

          logger.broadcast_to(logger_without_formatter)

          formatter = proc { |_level, _timestamp, _appname, message| "custom: #{message}" }
          logger.formatter = formatter
          expect(logger.formatter).to eq(formatter)
        end
      end
    end

    if DependencyHelper.rails_present?
      describe "wrapped in ActiveSupport::TaggedLogging" do
        let(:other_stream) { StringIO.new }
        let(:other_logger) { ::Logger.new(other_stream) }

        let(:logger) do
          appsignal_logger = Appsignal::Logger.new("group")
          appsignal_logger.broadcast_to(other_logger)
          ActiveSupport::TaggedLogging.new(appsignal_logger)
        end

        describe "broadcasts a tagged message to the given logger" do
          it "in agent mode", :agent_mode do
            expect(Appsignal::Extension).to receive(:log)
              .with(
                "group",
                3,
                3,
                "[My tag] [My other tag] Some message\n",
                Appsignal::Utils::Data.generate({})
              )

            logger.tagged("My tag", "My other tag") do
              logger.info("Some message")
            end

            expect(other_stream.string).to eq("[My tag] [My other tag] Some message\n")
          end

          it "in collector mode", :collector_mode do
            expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
              .with(
                "group",
                ::Logger::INFO,
                Appsignal::Logger::AUTODETECT,
                "[My tag] [My other tag] Some message\n",
                {}
              )

            logger.tagged("My tag", "My other tag") do
              logger.info("Some message")
            end

            expect(other_stream.string).to eq("[My tag] [My other tag] Some message\n")
          end
        end
      end
    end
  end

  [
    ["debug", 2, ::Logger::DEBUG, ::Logger::INFO],
    ["info", 3, ::Logger::INFO, ::Logger::WARN],
    ["warn", 5, ::Logger::WARN, ::Logger::ERROR],
    ["error", 6, ::Logger::ERROR, ::Logger::FATAL],
    ["fatal", 7, ::Logger::FATAL, nil]
  ].each do |permutation|
    method, extension_level, logger_level, higher_level = permutation

    describe "##{method}" do
      describe "with a message and attributes" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Utils::Data).to receive(:generate)
            .with({ :attribute => "value" })
            .and_call_original
          expect(Appsignal::Extension).to receive(:log)
            .with("group", extension_level, 3, "Log message", instance_of(Appsignal::Extension::Data))

          logger.send(method, "Log message", :attribute => "value")
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
            .with(
              "group",
              logger_level,
              Appsignal::Logger::AUTODETECT,
              "Log message",
              { :attribute => "value" }
            )

          logger.send(method, "Log message", :attribute => "value")
        end
      end

      describe "with a block" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Utils::Data).to receive(:generate)
            .with({})
            .and_call_original
          expect(Appsignal::Extension).to receive(:log)
            .with("group", extension_level, 3, "Log message", instance_of(Appsignal::Extension::Data))

          logger.send(method) { "Log message" }
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
            .with("group", logger_level, Appsignal::Logger::AUTODETECT, "Log message", {})

          logger.send(method) { "Log message" }
        end
      end

      describe "with a nil message" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Extension).not_to receive(:log)
          logger.send(method)
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).not_to receive(:emit)
          logger.send(method)
        end
      end

      if higher_level
        context "with a lower log level" do
          let(:logger) { Appsignal::Logger.new("group", :level => higher_level) }

          describe "skips logging when the level is too low" do
            it "in agent mode", :agent_mode do
              expect(Appsignal::Extension).not_to receive(:log)
              logger.send(method, "Log message")
            end

            it "in collector mode", :collector_mode do
              expect(Appsignal::Logger::OpenTelemetryBackend).not_to receive(:emit)
              logger.send(method, "Log message")
            end
          end
        end
      end

      context "with a formatter set" do
        before do
          Timecop.freeze(Time.local(2023))
          # The Ruby default Logger::Formatter expects a timestamp object as
          # the second argument (https://github.com/ruby/ruby/blob/master/lib/logger/formatter.rb#L15-L17).
          logger.formatter = proc do |_level, timestamp, _appname, message|
            time = timestamp.strftime("%Y-%m-%dT%H:%M:%S.%6N")
            "formatted: #{time} '#{message}'"
          end
        end

        after { Timecop.return }

        describe "logs the formatted message" do
          it "in agent mode", :agent_mode do
            expect(Appsignal::Extension).to receive(:log)
              .with(
                "group",
                extension_level,
                3,
                "formatted: 2023-01-01T00:00:00.000000 'Log message'",
                instance_of(Appsignal::Extension::Data)
              )
            logger.send(method, "Log message")
          end

          it "in collector mode", :collector_mode do
            expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
              .with(
                "group",
                logger_level,
                Appsignal::Logger::AUTODETECT,
                "formatted: 2023-01-01T00:00:00.000000 'Log message'",
                {}
              )
            logger.send(method, "Log message")
          end
        end
      end
    end
  end

  describe "a logger with default attributes" do
    describe "adds the attributes when a message is logged" do
      it "in agent mode", :agent_mode do
        logger = Appsignal::Logger.new("group", :attributes => { :some_key => "some_value" })

        expect(Appsignal::Extension).to receive(:log).with(
          "group", 6, 3, "Some message",
          Appsignal::Utils::Data.generate({ :other_key => "other_value", :some_key => "some_value" })
        )
        logger.error("Some message", { :other_key => "other_value" })
      end

      it "in collector mode", :collector_mode do
        logger = Appsignal::Logger.new("group", :attributes => { :some_key => "some_value" })

        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit).with(
          "group",
          ::Logger::ERROR,
          Appsignal::Logger::AUTODETECT,
          "Some message",
          { :other_key => "other_value", :some_key => "some_value" }
        )
        logger.error("Some message", { :other_key => "other_value" })
      end
    end

    describe "does not modify the original attribute hashes passed" do
      it_in_both_modes do
        default_attributes = { :some_key => "some_value" }
        logger = Appsignal::Logger.new("group", :attributes => default_attributes)

        line_attributes = { :other_key => "other_value" }
        logger.error("Some message", line_attributes)

        expect(default_attributes).to eq({ :some_key => "some_value" })
        expect(line_attributes).to eq({ :other_key => "other_value" })
      end
    end

    describe "prioritises line attributes over default attributes" do
      it "in agent mode", :agent_mode do
        logger = Appsignal::Logger.new("group", :attributes => { :some_key => "some_value" })

        expect(Appsignal::Extension).to receive(:log).with(
          "group", 6, 3, "Some message",
          Appsignal::Utils::Data.generate({ :some_key => "other_value" })
        )
        logger.error("Some message", { :some_key => "other_value" })
      end

      it "in collector mode", :collector_mode do
        logger = Appsignal::Logger.new("group", :attributes => { :some_key => "some_value" })

        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit).with(
          "group",
          ::Logger::ERROR,
          Appsignal::Logger::AUTODETECT,
          "Some message",
          { :some_key => "other_value" }
        )
        logger.error("Some message", { :some_key => "other_value" })
      end
    end

    describe "adds the default attributes when #add is called" do
      it "in agent mode", :agent_mode do
        logger = Appsignal::Logger.new("group", :attributes => { :some_key => "some_value" })

        expect(Appsignal::Extension).to receive(:log).with(
          "group", 3, 3, "Log message",
          Appsignal::Utils::Data.generate({ :some_key => "some_value" })
        )
        logger.add(::Logger::INFO, "Log message")
      end

      it "in collector mode", :collector_mode do
        logger = Appsignal::Logger.new("group", :attributes => { :some_key => "some_value" })

        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit).with(
          "group",
          ::Logger::INFO,
          Appsignal::Logger::AUTODETECT,
          "Log message",
          { :some_key => "some_value" }
        )
        logger.add(::Logger::INFO, "Log message")
      end
    end
  end

  describe "#error with exception object" do
    describe "logs the exception class and its message" do
      let(:error) do
        begin
          raise ExampleStandardError, "oh no!"
        rescue => e
          # Re-raise capture so the exception carries a backtrace, letting
          # us assert that its first line is part of the logged string.
          e
        end
      end

      it "in agent mode", :agent_mode do
        expect(Appsignal::Extension).to receive(:log)
          .with(
            "group",
            6,
            3,
            a_string_matching(/ExampleStandardError: oh no! \(.*logger_spec.rb.*\)/),
            instance_of(Appsignal::Extension::Data)
          )
        logger.error(error)
      end

      it "in collector mode", :collector_mode do
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with(
            "group",
            ::Logger::ERROR,
            Appsignal::Logger::AUTODETECT,
            a_string_matching(/ExampleStandardError: oh no! \(.*logger_spec.rb.*\)/),
            {}
          )
        logger.error(error)
      end
    end
  end

  describe "#<<" do
    describe "writes an info message and returns the number of characters written" do
      it "in agent mode", :agent_mode do
        expect(Appsignal::Extension).to receive(:log)
          .with("group", 3, 3, "hello there", instance_of(Appsignal::Extension::Data))

        message = "hello there"
        result = logger << message
        expect(result).to eq(message.length)
      end

      it "in collector mode", :collector_mode do
        expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit)
          .with("group", ::Logger::INFO, Appsignal::Logger::AUTODETECT, "hello there", {})

        message = "hello there"
        result = logger << message
        expect(result).to eq(message.length)
      end
    end

    context "with a formatter set" do
      before do
        logger.formatter = proc do |_level, _timestamp, _appname, message|
          "formatted: '#{message}'"
        end
      end

      # Documents how the logger currently behaves: a Ruby logger would
      # normally bypass the formatter for `<<`. We recommend against setting
      # a formatter on the AppSignal logger.
      describe "logs a formatted message" do
        it "in agent mode", :agent_mode do
          expect(Appsignal::Extension).to receive(:log).with(
            "group", 3, 3, "formatted: 'Log message'", instance_of(Appsignal::Extension::Data)
          )
          logger << "Log message"
        end

        it "in collector mode", :collector_mode do
          expect(Appsignal::Logger::OpenTelemetryBackend).to receive(:emit).with(
            "group", ::Logger::INFO, Appsignal::Logger::AUTODETECT, "formatted: 'Log message'", {}
          )
          logger << "Log message"
        end
      end
    end
  end

  if DependencyHelper.rails_present?
    describe "wrapped in ActiveSupport::TaggedLogging" do
      let(:logger) do
        appsignal_logger = Appsignal::Logger.new("group")
        ActiveSupport::TaggedLogging.new(appsignal_logger)
      end

      it_behaves_like "tagged logging"
    end
  end
end
