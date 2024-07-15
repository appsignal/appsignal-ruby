if DependencyHelper.grape_present?
  require "appsignal/integrations/grape"

  context "Appsignal::Grape::Middleware constant" do
    let(:err_stream) { std_stream }
    let(:stderr) { err_stream.read }

    it "returns the Rack::GrapeMiddleware constant calling the Grape::Middleware constant" do
      silence { expect(Appsignal::Grape::Middleware).to be(Appsignal::Rack::GrapeMiddleware) }
    end

    it "prints a deprecation warning to STDERR" do
      capture_std_streams(std_stream, err_stream) do
        expect(Appsignal::Grape::Middleware).to be(Appsignal::Rack::GrapeMiddleware)
      end

      expect(stderr).to include(
        "appsignal WARNING: The constant Appsignal::Grape::Middleware has been deprecated."
      )
    end

    it "logs a warning" do
      logs =
        capture_logs do
          silence do
            expect(Appsignal::Grape::Middleware).to be(Appsignal::Rack::GrapeMiddleware)
          end
        end

      expect(logs).to contains_log(
        :warn,
        "The constant Appsignal::Grape::Middleware has been deprecated."
      )
    end
  end
end
