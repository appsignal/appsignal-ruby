describe Appsignal::Logger do
  let(:logger) { Appsignal::Logger.new("group", :level => ::Logger::DEBUG) }

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

    it "should log when using `group` for the log message" do
      expect(Appsignal::Extension).to receive(:log)
        .with("group", 3, 0, "Log message", instance_of(Appsignal::Extension::Data))
      logger.add(::Logger::INFO, nil, "Log message")
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
  end

  [
    ["debug", 2, ::Logger::INFO],
    ["info", 3, ::Logger::WARN],
    ["warn", 5, ::Logger::ERROR],
    ["error", 6, ::Logger::FATAL],
    ["fatal", 7, nil]
  ].each do |method|
    describe "##{method[0]}" do
      it "should log with a message" do
        expect(Appsignal::Utils::Data).to receive(:generate)
          .with({ :attribute => "value" })
          .and_call_original
        expect(Appsignal::Extension).to receive(:log)
          .with("group", method[1], 0, "Log message", instance_of(Appsignal::Extension::Data))

        logger.send(method[0], "Log message", :attribute => "value")
      end

      it "should log with a block" do
        expect(Appsignal::Utils::Data).to receive(:generate)
          .with({})
          .and_call_original
        expect(Appsignal::Extension).to receive(:log)
          .with("group", method[1], 0, "Log message", instance_of(Appsignal::Extension::Data))

        logger.send(method[0]) do
          "Log message"
        end
      end

      it "should return with a nil message" do
        expect(Appsignal::Extension).not_to receive(:log)
        logger.send(method[0])
      end

      if method[2]
        context "with a lower log level" do
          let(:logger) { Appsignal::Logger.new("group", :level => method[2]) }

          it "should skip logging if the level is too low" do
            expect(Appsignal::Extension).not_to receive(:log)
            logger.send(method[0], "Log message")
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
              method[1],
              0,
              "formatted: 2023-01-01T00:00:00.000000 'Log message'",
              instance_of(Appsignal::Extension::Data)
            )
          logger.send(method[0], "Log message")
        end
      end
    end
  end
end
