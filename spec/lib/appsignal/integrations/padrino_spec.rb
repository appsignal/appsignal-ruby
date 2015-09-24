require 'spec_helper'

begin
  require 'padrino'
rescue LoadError
end

if padrino_present?
  describe "Padrino integration"   do
    require File.expand_path('lib/appsignal/integrations/padrino.rb')

    class ClassWithRouter
      include Padrino::Routing
    end

    before do
      Appsignal.stub(
        :active?      => true,
        :start        => true,
        :start_logger => true
      )
    end

    describe "Appsignal::Integrations::PadrinoPlugin" do
      it "should start the logger on init" do
        expect( Appsignal ).to receive(:start_logger)
      end

      it "should start appsignal on init" do
        expect( Appsignal ).to receive(:start)
      end

      context "when not active" do
        before { Appsignal.stub(:active? => false) }

        it "should not add the Listener middleware to the stack" do
          expect( Padrino ).to_not receive(:use)
        end
      end

      after { Appsignal::Integrations::PadrinoPlugin.init }
    end

    describe "Padrino::Routing::InstanceMethods" do
      let(:base)     { double }
      let(:router)   { ClassWithRouter.new }
      let(:env)      { {} }
      let(:settings) { double(:name => 'TestApp') }

      describe "#route!" do
        let(:request) do
          double(
            :params          => {'id' => 1},
            :session         => {'user_id' => 123},
            :request_method  => 'GET',
            :path            => '/users/1',
            :controller      => 'users',
            :action          => 'show',
            :env             => {}
          )
        end

        before do
          router.stub(
            :route_without_appsignal => true,
            :request                 => request,
            :env                     => env,
            :settings                => settings,
            :get_payload_action      => 'controller#action'
          )
        end

        context "when Sinatra tells us it's a static file" do
          let(:env) { {'sinatra.static_file' => true} }

          it "should call the original method" do
            expect( router ).to receive(:route_without_appsignal)
          end

          it "should not instrument the request" do
            expect( ActiveSupport::Notifications ).to_not receive(:instrument)
          end

          after { router.route!(base) }
        end

        context "when appsignal is not active" do
          before { Appsignal.stub(:active? => false) }

          it "should call the original method" do
            expect( router ).to receive(:route_without_appsignal)
          end

          it "should not instrument the request" do
            expect( ActiveSupport::Notifications ).to_not receive(:instrument)
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
          before { Appsignal::Transaction.stub(:create => transaction) }

          context "without an error" do
            it "should create a transaction" do
              expect( Appsignal::Transaction ).to receive(:create).with(
                kind_of(String),
                Appsignal::Transaction::HTTP_REQUEST,
                request
              ).and_return(transaction)
            end

            it "should call the original routing method" do
              expect( router ).to receive(:route_without_appsignal)
            end

            it "should instrument the action" do
              expect( ActiveSupport::Notifications ).to receive(:instrument).with('process_action.padrino')
            end

            it "should set metadata" do
              expect( transaction ).to receive(:set_metadata).twice
            end

            it "should set the action on the transaction" do
              expect( transaction ).to receive(:set_action).with('controller#action')
            end

            after { router.route!(base) }
          end

          context "with an error" do
            let(:error) { VerySpecificError.new }
            before { router.stub(:route_without_appsignal).and_raise(error) }

            it "should add the exception to the current transaction" do
              expect( transaction ).to receive(:set_error).with(error)

              router.route!(base) rescue VerySpecificError
            end
          end
        end
      end

      describe "#get_payload_action" do
        before { router.stub(:settings  => settings) }

        context "when request is nil" do
          it "should return the site" do
            expect( router.get_payload_action(nil) ).to eql('TestApp')
          end
        end

        context "when there's no route object" do
          let(:request) { double(:controller => 'Controller', :action => 'action') }

          it "should return the site name, controller and action" do
            expect( router.get_payload_action(request) ).to eql('TestApp:Controller#action')
          end

          context "when there's no action" do
            let(:request) { double(:controller => 'Controller', :fullpath => '/action') }

            it "should return the site name, controller and fullpath" do
              expect( router.get_payload_action(request) ).to eql('TestApp:Controller#/action')
            end
          end
        end

        context "when request has a route object" do
          let(:request)      { double }
          let(:route_object) { double(:original_path => '/accounts/edit/:id') }
          before             { request.stub(:route_obj => route_object) }

          it "should return the original path" do
            expect( router.get_payload_action(request) ).to eql('TestApp:/accounts/edit/:id')
          end
        end
      end
    end
  end
end
