if sinatra_present? && !padrino_present?
  ENV['APPSIGNAL_PUSH_API_KEY'] = 'key'
  require 'appsignal/integrations/sinatra'

  describe "Sinatra integration" do
    context "Appsignal.logger" do
      subject { Appsignal.logger }

      it { should be_a Logger }
    end

    describe "middleware" do
      it "adds the instrumentation middleware to Sinatra::Base" do
        Sinatra::Base.middleware.to_a.should include(
          [Appsignal::Rack::SinatraBaseInstrumentation, [], nil]
        )
      end
    end

    describe "environment" do
      subject { Appsignal.config.env }

      context "without APPSIGNAL_APP_ENV" do
        before do
          load File.expand_path('lib/appsignal/integrations/sinatra.rb', project_dir)
        end

        it "uses the app environment" do
          expect(subject).to eq('test')
        end
      end

      context "with APPSIGNAL_APP_ENV" do
        before do
          ENV['APPSIGNAL_APP_ENV'] = 'env-staging'
          load File.expand_path('lib/appsignal/integrations/sinatra.rb', project_dir)
        end

        it "uses the environment variable" do
          expect(subject).to eq('env-staging')
        end
      end
    end
  end
end
