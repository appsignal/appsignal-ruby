describe Appsignal::Hooks::SidekiqHook do
  describe "#dependencies_present?" do
    subject { described_class.new.dependencies_present? }

    context "when Sidekiq constant is found" do
      before { stub_const "Sidekiq", Class.new }

      it { is_expected.to be_truthy }
    end

    context "when Sidekiq constant is not found" do
      before { hide_const "Sidekiq" }

      it { is_expected.to be_falsy }
    end
  end

  describe "#install" do
    class SidekiqMiddlewareMockWithPrepend < Array
      alias add <<
      alias exists? include?

      unless method_defined? :prepend
        # For Ruby < 2.5
        def prepend(middleware)
          insert(0, middleware)
        end
      end
    end

    class SidekiqMiddlewareMockWithoutPrepend < Array
      alias add <<
      alias exists? include?

      undef_method :prepend if method_defined? :prepend # For Ruby >= 2.5
    end

    module SidekiqMock
      def self.middleware_mock=(mock)
        @middlewares = mock.new
      end

      def self.middlewares
        @middlewares
      end

      def self.configure_server
        yield self
      end

      def self.server_middleware
        yield middlewares if block_given?
        middlewares
      end

      def self.error_handlers
        @error_handlers ||= []
      end
    end

    def add_middleware(middleware)
      Sidekiq.configure_server do |sidekiq_config|
        sidekiq_config.middlewares.add(middleware)
      end
    end

    before do
      Appsignal.config = project_fixture_config
      stub_const "Sidekiq", SidekiqMock
    end

    it "adds error handler" do
      Sidekiq.middleware_mock = SidekiqMiddlewareMockWithPrepend
      described_class.new.install
      expect(Sidekiq.error_handlers).to include(Appsignal::Integrations::SidekiqErrorHandler)
    end

    context "when Sidekiq middleware responds to prepend method" do # Sidekiq 3.3.0 and newer
      before { Sidekiq.middleware_mock = SidekiqMiddlewareMockWithPrepend }

      it "adds the AppSignal SidekiqPlugin to the Sidekiq middleware chain in the first position" do
        user_middleware1 = proc {}
        add_middleware(user_middleware1)
        described_class.new.install
        user_middleware2 = proc {}
        add_middleware(user_middleware2)

        expect(Sidekiq.server_middleware).to eql([
          Appsignal::Integrations::SidekiqMiddleware, # Prepend makes it the first entry
          user_middleware1,
          user_middleware2
        ])
      end
    end

    context "when Sidekiq middleware does not respond to prepend method" do
      before { Sidekiq.middleware_mock = SidekiqMiddlewareMockWithoutPrepend }

      it "adds the AppSignal SidekiqPlugin to the Sidekiq middleware chain" do
        user_middleware1 = proc {}
        add_middleware(user_middleware1)
        described_class.new.install
        user_middleware2 = proc {}
        add_middleware(user_middleware2)

        # Add middlewares in whatever order they were added
        expect(Sidekiq.server_middleware).to eql([
          user_middleware1,
          Appsignal::Integrations::SidekiqMiddleware,
          user_middleware2
        ])
      end
    end
  end
end
