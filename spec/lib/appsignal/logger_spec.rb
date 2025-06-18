shared_examples "tagged logging" do
  it "logs messages with tags from logger.tagged" do
    expect(Appsignal::Extension).to receive(:log)
      .with(
        "group",
        3,
        0,
        "[My tag] [My other tag] Some message\n",
        Appsignal::Utils::Data.generate({})
      )

    logger.tagged("My tag", "My other tag") do
      logger.info("Some message")
    end
  end

  it "logs messages with nested tags from logger.tagged" do
    expect(Appsignal::Extension).to receive(:log)
      .with(
        "group",
        3,
        0,
        "[My tag] [My other tag] [Nested tag] [Nested other tag] Some message\n",
        Appsignal::Utils::Data.generate({})
      )

    logger.tagged("My tag", "My other tag") do
      logger.tagged("Nested tag", "Nested other tag") do
        logger.info("Some message")
      end
    end
  end

  it "logs messages with tags from Rails.application.config.log_tags" do
    allow(Appsignal::Extension).to receive(:log)

    # This is how Rails sets the `log_tags` values
    logger.push_tags(["Request tag", "Second tag"])
    logger.tagged("First message", "My other tag") { logger.info("Some message") }
    expect(Appsignal::Extension).to have_received(:log)
      .with(
        "group",
        3,
        0,
        "[Request tag] [Second tag] [First message] [My other tag] Some message\n",
        Appsignal::Utils::Data.generate({})
      )

    # Logs all messsages within the time between `push_tags` and `pop_tags`
    # with the same set tags
    logger.tagged("Second message") { logger.info("Some message") }
    expect(Appsignal::Extension).to have_received(:log)
      .with(
        "group",
        3,
        0,
        "[Request tag] [Second tag] [Second message] Some message\n",
        Appsignal::Utils::Data.generate({})
      )

    # This is how Rails clears the `log_tags` values
    # It will no longer includes those tags in new log messages
    logger.pop_tags(2)
    logger.tagged("Third message") { logger.info("Some message") }
    expect(Appsignal::Extension).to have_received(:log)
      .with(
        "group",
        3,
        0,
        "[Third message] Some message\n",
        Appsignal::Utils::Data.generate({})
      )
  end

  it "logs messages with tags from Rails 8 application.config.log_tags" do
    allow(Appsignal::Extension).to receive(:log)

    # This is how Rails sets the `log_tags` values
    logger.push_tags("Request tag", "Second tag")
    logger.tagged("First message", "My other tag") { logger.info("Some message") }
    expect(Appsignal::Extension).to have_received(:log)
      .with(
        "group",
        3,
        0,
        "[Request tag] [Second tag] [First message] [My other tag] Some message\n",
        Appsignal::Utils::Data.generate({})
      )
  end

  it "clears all tags with clear_tags!" do
    allow(Appsignal::Extension).to receive(:log)

    # This is how Rails sets the `log_tags` values
    logger.push_tags(["Request tag", "Second tag"])
    logger.tagged("First message", "My other tag") { logger.info("Some message") }
    expect(Appsignal::Extension).to have_received(:log)
      .with(
        "group",
        3,
        0,
        "[Request tag] [Second tag] [First message] [My other tag] Some message\n",
        Appsignal::Utils::Data.generate({})
      )

    logger.clear_tags!
    logger.tagged("First message", "My other tag") { logger.info("Some message") }
    expect(Appsignal::Extension).to have_received(:log)
      .with(
        "group",
        3,
        0,
        "[First message] [My other tag] Some message\n",
        Appsignal::Utils::Data.generate({})
      )
  end

  it "accepts tags in #tagged as an array" do
    expect(Appsignal::Extension).to receive(:log)
      .with(
        "group",
        3,
        0,
        "[My tag] [My other tag] Some message\n",
        Appsignal::Utils::Data.generate({})
      )

    logger.tagged(["My tag", "My other tag"]) do
      logger.info("Some message")
    end
  end

  # Calling `#tagged` without a block is not supported by
  # `ActiveSupport::TaggedLogging` in Rails 6 and earlier. Only run this
  # in builds where Rails is not present, or builds where Rails 7 or later
  # is present.
  if !DependencyHelper.rails_present? || DependencyHelper.rails7_present?
    describe "when calling #tagged without a block" do
      it "returns a new logger with the tags added" do
        expect(Appsignal::Extension).to receive(:log)
          .with(
            "group",
            3,
            0,
            "[My tag] [My other tag] Some message\n",
            Appsignal::Utils::Data.generate({})
          )

        logger.tagged("My tag", "My other tag").info("Some message")
      end

      it "does not modify the original logger" do
        expect(Appsignal::Extension).to receive(:log)
          .with(
            "group",
            3,
            0,
            "[My tag] [My other tag] Some message\n",
            Appsignal::Utils::Data.generate({})
          )

        new_logger = logger.tagged("My tag", "My other tag")
        new_logger.info("Some message")

        expect(Appsignal::Extension).to receive(:log)
          .with(
            "group",
            3,
            0,
            "Some message\n",
            Appsignal::Utils::Data.generate({})
          )

        logger.info("Some message")
      end

      it "can be chained" do
        expect(Appsignal::Extension).to receive(:log)
          .with(
            "group",
            3,
            0,
            "[My tag] [My other tag] [My third tag] Some message\n",
            Appsignal::Utils::Data.generate({})
          )

        logger.tagged("My tag", "My other tag").tagged("My third tag").info("Some message")
      end

      it "can be chained before a block invocation" do
        expect(Appsignal::Extension).to receive(:log)
          .with(
            "group",
            3,
            0,
            "[My tag] [My other tag] [My third tag] Some message\n",
            Appsignal::Utils::Data.generate({})
          )

        # We must explicitly use the logger passed to the block,
        # as the logger returned from the first #tagged invocation
        # is a new instance of the logger.
        logger.tagged("My tag", "My other tag").tagged("My third tag") do |logger|
          logger.info("Some message")
        end
      end

      it "can be chained after a block invocation" do
        expect(Appsignal::Extension).to receive(:log)
          .with(
            "group",
            3,
            0,
            "[My tag] [My other tag] [My third tag] Some message\n",
            Appsignal::Utils::Data.generate({})
          )

        logger.tagged("My tag", "My other tag") do
          logger.tagged("My third tag").info("Some message")
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

  describe "#add" do
    it "should log with a level and message" do
      expect(Appsignal::Extension).to receive(:log)
        .with("group", 3, 0, "Log message", instance_of(Appsignal::Extension::Data))
      logger.add(::Logger::INFO, "Log message")
    end

    it "calls #to_s on the message" do
      expect(Appsignal::Extension).to receive(:log)
        .with("group", 3, 0, "123", instance_of(Appsignal::Extension::Data))
      expect(Appsignal::Extension).to receive(:log)
        .with("group", 3, 0, "{}", instance_of(Appsignal::Extension::Data))
      expect(Appsignal::Extension).to receive(:log)
        .with("group", 3, 0, "[]", instance_of(Appsignal::Extension::Data))
      logger.add(::Logger::INFO, 123)
      logger.add(::Logger::INFO, {})
      logger.add(::Logger::INFO, [])
    end

    it "does not log a message that cannot be converted to a String" do
      expect(Appsignal::Extension).to_not receive(:log)

      object = Object.new
      class << object
        undef_method :to_s
      end

      logger.add(::Logger::INFO, object)
      expect(logs)
        .to contains_log(:warn, "Logger message was ignored, because it was not a String: #<Object")
    end

    it "should log with a block" do
      expect(Appsignal::Extension).to receive(:log)
        .with("group", 3, 0, "Log message", instance_of(Appsignal::Extension::Data))
      logger.add(::Logger::INFO) do
        "Log message"
      end
    end

    it "should log with a level, message and group" do
      expect(Appsignal::Extension).to receive(:log)
        .with("other_group", 3, 0, "Log message", instance_of(Appsignal::Extension::Data))
      logger.add(::Logger::INFO, "Log message", "other_group")
    end

    context "with info log level" do
      let(:logger) { Appsignal::Logger.new("group", :level => ::Logger::INFO) }

      it "should skip logging if the level is too low" do
        expect(Appsignal::Extension).not_to receive(:log)
        logger.add(::Logger::DEBUG, "Log message")
      end
    end

    context "with a format set" do
      let(:logger) { Appsignal::Logger.new("group", :format => Appsignal::Logger::LOGFMT) }

      it "should log and pass the format flag" do
        expect(Appsignal::Extension).to receive(:log)
          .with("group", 3, 1, "Log message", instance_of(Appsignal::Extension::Data))
        logger.add(::Logger::INFO, "Log message")
      end
    end

    context "with a formatter set" do
      before do
        logger.formatter = proc do |_level, _timestamp, _appname, message|
          "formatted: '#{message}'"
        end
      end

      it "should log with a level, message and group" do
        expect(Appsignal::Extension).to receive(:log).with(
          "other_group",
          3,
          0,
          "formatted: 'Log message'",
          instance_of(Appsignal::Extension::Data)
        )
        logger.add(::Logger::INFO, "Log message", "other_group")
      end
    end
  end

  describe "#silence" do
    it "calls the given block" do
      num = 1

      logger.silence do
        num += 1
      end

      expect(num).to eq(2)
      expect(Appsignal::Extension).not_to receive(:log)
    end

    it "silences the logger up to, but not including, the given level" do
      # Expect not to receive info
      expect(Appsignal::Extension).not_to receive(:log)
        .with("group", 3, 0, "Log message", instance_of(Appsignal::Extension::Data))

      # Expect to receive warn
      expect(Appsignal::Extension).to receive(:log)
        .with("group", 5, 0, "Log message", instance_of(Appsignal::Extension::Data))

      logger.silence(::Logger::WARN) do
        logger.info("Log message")
        logger.warn("Log message")
      end
    end

    it "silences the logger to error level by default" do
      # Expect not to receive debug, info or warn
      [2, 3, 5].each do |severity|
        expect(Appsignal::Extension).not_to receive(:log)
          .with("group", severity, 0, "Log message", instance_of(Appsignal::Extension::Data))
      end

      # Expect to receive error and fatal
      [6, 7].each do |severity|
        expect(Appsignal::Extension).to receive(:log)
          .with("group", severity, 0, "Log message", instance_of(Appsignal::Extension::Data))
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

  describe "#broadcast_to" do
    it "broadcasts the message to the given logger" do
      other_device = StringIO.new
      other_logger = ::Logger.new(other_device)

      logger.broadcast_to(other_logger)

      expect(Appsignal::Extension).to receive(:log)
        .with("group", 3, 0, "Log message", instance_of(Appsignal::Extension::Data))

      logger.info("Log message")

      expect(other_device.string).to include("INFO -- group: Log message")
    end

    it "broadcasts the message to the given logger when it's below the log level" do
      logger = Appsignal::Logger.new("group", :level => ::Logger::INFO)

      other_device = StringIO.new
      other_logger = ::Logger.new(other_device)

      logger.broadcast_to(other_logger)

      expect(Appsignal::Extension).not_to receive(:log)

      logger.debug("Log message")

      expect(other_device.string).to include("DEBUG -- group: Log message")
    end

    it "does not broadcast the message to the given logger when silenced" do
      other_device = StringIO.new
      other_logger = ::Logger.new(other_device)

      logger.broadcast_to(other_logger)

      expect(Appsignal::Extension).not_to receive(:log)

      logger.silence do
        logger.info("Log message")
      end

      expect(other_device.string).to eq("")
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

        it "broadcasts a tagged message to the given logger" do
          expect(Appsignal::Extension).to receive(:log)
            .with(
              "group",
              3,
              0,
              "[My tag] [My other tag] Some message\n",
              Appsignal::Utils::Data.generate({})
            )

          logger.tagged("My tag", "My other tag") do
            logger.info("Some message")
          end

          expect(other_stream.string)
            .to eq("[My tag] [My other tag] Some message\n")
        end
      end
    end
  end

  [
    ["debug", 2, ::Logger::INFO],
    ["info", 3, ::Logger::WARN],
    ["warn", 5, ::Logger::ERROR],
    ["error", 6, ::Logger::FATAL],
    ["fatal", 7, nil]
  ].each do |permutation|
    method, extension_level, higher_level = permutation

    describe "##{method}" do
      it "should log with a message" do
        expect(Appsignal::Utils::Data).to receive(:generate)
          .with({ :attribute => "value" })
          .and_call_original
        expect(Appsignal::Extension).to receive(:log)
          .with("group", extension_level, 0, "Log message", instance_of(Appsignal::Extension::Data))

        logger.send(method, "Log message", :attribute => "value")
      end

      it "should log with a block" do
        expect(Appsignal::Utils::Data).to receive(:generate)
          .with({})
          .and_call_original
        expect(Appsignal::Extension).to receive(:log)
          .with("group", extension_level, 0, "Log message", instance_of(Appsignal::Extension::Data))

        logger.send(method) do
          "Log message"
        end
      end

      it "should return with a nil message" do
        expect(Appsignal::Extension).not_to receive(:log)
        logger.send(method)
      end

      if higher_level
        context "with a lower log level" do
          let(:logger) { Appsignal::Logger.new("group", :level => higher_level) }

          it "should skip logging if the level is too low" do
            expect(Appsignal::Extension).not_to receive(:log)
            logger.send(method, "Log message")
          end
        end
      end

      context "with a formatter set" do
        before do
          Timecop.freeze(Time.local(2023))
          logger.formatter = logger.formatter = proc do |_level, timestamp, _appname, message|
            # This line replicates the behaviour of the Ruby default Logger::Formatter
            # which expects a timestamp object as a second argument
            # https://github.com/ruby/ruby/blob/master/lib/logger/formatter.rb#L15-L17
            time = timestamp.strftime("%Y-%m-%dT%H:%M:%S.%6N")
            "formatted: #{time} '#{message}'"
          end
        end

        after do
          Timecop.return
        end

        it "should log with a level, message and group" do
          expect(Appsignal::Extension).to receive(:log)
            .with(
              "group",
              extension_level,
              0,
              "formatted: 2023-01-01T00:00:00.000000 'Log message'",
              instance_of(Appsignal::Extension::Data)
            )
          logger.send(method, "Log message")
        end
      end
    end
  end

  describe "a logger with default attributes" do
    it "adds the attributes when a message is logged" do
      logger = Appsignal::Logger.new("group", :attributes => { :some_key => "some_value" })

      expect(Appsignal::Extension).to receive(:log).with("group", 6, 0, "Some message",
        Appsignal::Utils::Data.generate({ :other_key => "other_value", :some_key => "some_value" }))
      logger.error("Some message", { :other_key => "other_value" })
    end

    it "does not modify the original attribute hashes passed" do
      default_attributes = { :some_key => "some_value" }
      logger = Appsignal::Logger.new("group", :attributes => default_attributes)

      line_attributes = { :other_key => "other_value" }
      logger.error("Some message", line_attributes)

      expect(default_attributes).to eq({ :some_key => "some_value" })
      expect(line_attributes).to eq({ :other_key => "other_value" })
    end

    it "prioritises line attributes over default attributes" do
      logger = Appsignal::Logger.new("group", :attributes => { :some_key => "some_value" })

      expect(Appsignal::Extension).to receive(:log).with("group", 6, 0, "Some message",
        Appsignal::Utils::Data.generate({ :some_key => "other_value" }))

      logger.error("Some message", { :some_key => "other_value" })
    end

    it "adds the default attributes when #add is called" do
      logger = Appsignal::Logger.new("group", :attributes => { :some_key => "some_value" })

      expect(Appsignal::Extension).to receive(:log).with("group", 3, 0, "Log message",
        Appsignal::Utils::Data.generate({ :some_key => "some_value" }))
      logger.add(::Logger::INFO, "Log message")
    end
  end

  describe "#error with exception object" do
    it "logs the exception class and its message" do
      error =
        begin
          raise ExampleStandardError, "oh no!"
        rescue => e
          # This makes the exception include a backtrace, so we can assert it's NOT included
          e
        end
      expect(Appsignal::Extension).to receive(:log)
        .with(
          "group",
          6,
          0,
          "ExampleStandardError: oh no!",
          instance_of(Appsignal::Extension::Data)
        )
      logger.error(error)
    end
  end

  describe "#<<" do
    it "writes an info message and returns the number of characters written" do
      expect(Appsignal::Extension).to receive(:log)
        .with(
          "group",
          3,
          0,
          "hello there",
          instance_of(Appsignal::Extension::Data)
        )

      message = "hello there"
      result = logger << message
      expect(result).to eq(message.length)
    end

    context "with a formatter set" do
      before do
        logger.formatter = proc do |_level, _timestamp, _appname, message|
          "formatted: '#{message}'"
        end
      end

      # This documents how the logger currently behaves in this scenario.
      # Normally a Ruby logger would ignore the logger.
      # We would recommend not setting a logger on the AppSignal logger.
      it "logs a formatted message" do
        expect(Appsignal::Extension).to receive(:log).with(
          "group",
          3,
          0,
          "formatted: 'Log message'",
          instance_of(Appsignal::Extension::Data)
        )
        logger << "Log message"
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
