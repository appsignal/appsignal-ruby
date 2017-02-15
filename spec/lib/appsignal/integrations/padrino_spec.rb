if DependencyHelper.padrino_present?
  describe "Padrino integration" do
    require File.expand_path("lib/appsignal/integrations/padrino.rb")

    class ClassWithRouter
      include Padrino::Routing
    end

    before do
      allow(Appsignal).to receive(:active?).and_return(true)
      allow(Appsignal).to receive(:start).and_return(true)
      allow(Appsignal).to receive(:start_logger).and_return(true)
    end

    describe "Appsignal::Integrations::PadrinoPlugin" do
      it "should start the logger on init" do
        expect(Appsignal).to receive(:start_logger)
      end

      it "should start appsignal on init" do
        expect(Appsignal).to receive(:start)
      end

      context "when not active" do
        before { allow(Appsignal).to receive(:active?).and_return(false) }

        it "should not add the Listener middleware to the stack" do
          expect(Padrino).to_not receive(:use)
        end
      end

      context "when APPSIGNAL_APP_ENV ENV var is provided" do
        it "should use this as the environment" do
          ENV["APPSIGNAL_APP_ENV"] = "custom"

          # Reset the plugin to pull down the latest data
          Appsignal::Integrations::PadrinoPlugin.init

          expect(Appsignal.config.env).to eq "custom"
        end
      end

      context "when APPSIGNAL_APP_ENV ENV var is not provided" do
        it "should use the Padrino environment" do
          ENV["APPSIGNAL_APP_ENV"] = nil

          # Reset the plugin to pull down the latest data
          Appsignal::Integrations::PadrinoPlugin.init

          expect(Appsignal.config.env).to eq Padrino.env.to_s
        end
      end

      after { Appsignal::Integrations::PadrinoPlugin.init }
    end

    describe "Padrino::Routing::InstanceMethods" do
      let(:base)     { double }
      let(:router)   { ClassWithRouter.new }
      let(:env)      { {} }
      let(:settings) { double(:name => "TestApp") }

      describe "#route!" do
        let(:request) do
          double(
            :params          => { "id" => 1 },
            :session         => { "user_id" => 123 },
            :request_method  => "GET",
            :path            => "/users/1",
            :controller      => "users",
            :action          => "show",
            :env             => {}
          )
        end

        before do
          allow(router).to receive(:route_without_appsignal).and_return(true)
          allow(router).to receive(:request).and_return(request)
          allow(router).to receive(:env).and_return(env)
          allow(router).to receive(:settings).and_return(settings)
          allow(router).to receive(:get_payload_action).and_return("controller#action")
        end

        context "when Sinatra tells us it's a static file" do
          let(:env) { { "sinatra.static_file" => true } }

          it "should call the original method" do
            expect(router).to receive(:route_without_appsignal)
          end

          it "should not instrument the request" do
            expect(Appsignal).to_not receive(:instrument)
          end

          after { router.route!(base) }
        end

        context "when appsignal is not active" do
          before { allow(Appsignal).to receive(:active?).and_return(false) }

          it "should call the original method" do
            expect(router).to receive(:route_without_appsignal)
          end

          it "should not instrument the request" do
            expect(Appsignal).to_not receive(:instrument)
          end

          after { router.route!(base) }
        end

        context "with a dynamic request" do
          let(:transaction) do
            double(
              :set_http_or_background_action => nil,
              :set_http_or_background_queue_start => nil,
              :set_metadata => nil,
              :set_action => nil,
              :set_error => nil
            )
          end
          before { allow(Appsignal::Transaction).to receive(:create).and_return(transaction) }

          context "without an error" do
            it "should create a transaction" do
              expect(Appsignal::Transaction).to receive(:create).with(
                kind_of(String),
                Appsignal::Transaction::HTTP_REQUEST,
                request
              ).and_return(transaction)
            end

            it "should call the original routing method" do
              expect(router).to receive(:route_without_appsignal)
            end

            it "should instrument the action" do
              expect(Appsignal).to receive(:instrument).with("process_action.padrino")
            end

            it "should set metadata" do
              expect(transaction).to receive(:set_metadata).twice
            end

            it "should set the action on the transaction" do
              expect(transaction).to receive(:set_action_if_nil).with("controller#action")
            end

            after { router.route!(base) }
          end

          context "with an error" do
            let(:error) { VerySpecificError.new }
            before { allow(router).to receive(:route_without_appsignal).and_raise(error) }

            it "should add the exception to the current transaction" do
              expect(transaction).to receive(:set_error).with(error)

              router.route!(base) rescue VerySpecificError
            end
          end
        end
      end

      describe "#get_payload_action" do
        before { allow(router).to receive(:settings).and_return(settings) }

        context "when request is nil" do
          it "should return the site" do
            expect(router.get_payload_action(nil)).to eql("TestApp")
          end
        end

        context "when there's no route object" do
          let(:request) { double(:controller => "Controller", :action => "action") }

          it "should return the site name, controller and action" do
            expect(router.get_payload_action(request)).to eql("TestApp:Controller#action")
          end

          context "when there's no action" do
            let(:request) { double(:controller => "Controller", :fullpath => "/action") }

            it "should return the site name, controller and fullpath" do
              expect(router.get_payload_action(request)).to eql("TestApp:Controller#/action")
            end
          end
        end

        context "when request has a route object" do
          let(:request)      { double }
          let(:route_object) { double(:original_path => "/accounts/edit/:id") }
          before             { allow(request).to receive(:route_obj).and_return(route_object) }

          it "should return the original path" do
            expect(router.get_payload_action(request)).to eql("TestApp:/accounts/edit/:id")
          end
        end
      end
    end
  end
end
