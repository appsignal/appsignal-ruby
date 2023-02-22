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

    it "should return with a nil message" do
      expect(Appsignal::Extension).not_to receive(:log)
      logger.add(::Logger::INFO, nil)
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
        expect(Appsignal::Extension).to receive(:log)
          .with("other_group", 3, 0, "formatted: 'Log message'", instance_of(Appsignal::Extension::Data))
        logger.add(::Logger::INFO, "Log message", "other_group")
      end
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
          .with({})
          .and_call_original
        expect(Appsignal::Extension).to receive(:log)
          .with("group", method[1], 0, "Log message", instance_of(Appsignal::Extension::Data))

        logger.send(method[0], "Log message")
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
          logger.formatter = proc do |_level, _timestamp, _appname, message|
            "formatted: '#{message}'"
          end
        end

        it "should log with a level, message and group" do
          expect(Appsignal::Extension).to receive(:log)
            .with("group", method[1], 0, "formatted: 'Log message'", instance_of(Appsignal::Extension::Data))
          logger.send(method[0], "Log message")
        end
      end
    end
  end
end
