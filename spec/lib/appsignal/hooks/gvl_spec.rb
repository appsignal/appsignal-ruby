describe Appsignal::Hooks::GvlHook do
  if DependencyHelper.running_jruby?
    context "running JRuby" do
      it "does not attempt to require GVLTools" do
        expect_any_instance_of(described_class).not_to receive(:require).with("gvltools")
        expect(described_class.new.dependencies_present?).to be_falsy
      end
    end
  else
    before(:context) do
      Appsignal.config = project_fixture_config
    end

    def expect_gvltools_require
      expect_any_instance_of(described_class).to receive(:require).with("gvltools").and_return(true)
    end

    context "without GVLTools" do
      describe "#dependencies_present?" do
        context "if requiring gvltools fails" do
          it "is false" do
            expect(described_class.new.dependencies_present?).to be_falsy
          end
        end

        it "is false" do
          expect_gvltools_require
          expect(described_class.new.dependencies_present?).to be_falsy
        end
      end
    end

    context "with old versions of GVLTools" do
      before(:context) do
        module GVLTools
          VERSION = "0.1.0".freeze
        end
      end

      after(:context) { Object.send(:remove_const, :GVLTools) }

      before(:each) { expect_gvltools_require }

      describe "#dependencies_present?" do
        it "is false" do
          expect(described_class.new.dependencies_present?).to be_falsy
        end
      end
    end

    context "with new versions of GVLTools" do
      before(:context) do
        module GVLTools
          VERSION = "0.2.0".freeze

          module GlobalTimer
            def self.enable
            end
          end

          module WaitingThreads
            def self.enable
            end
          end
        end
      end

      after(:context) { Object.send(:remove_const, :GVLTools) }

      describe "#dependencies_present?" do
        before(:each) { expect_gvltools_require }

        if DependencyHelper.ruby_3_2_or_newer?
          it "is true" do
            expect(described_class.new.dependencies_present?).to be_truthy
          end
        else
          it "is false" do
            expect(described_class.new.dependencies_present?).to be_falsy
          end
        end
      end

      if DependencyHelper.ruby_3_2_or_newer?
        describe "Appsignal::Hooks.load_hooks" do
          before(:each) { expect_gvltools_require }

          # After installing a hook once, it is marked as already installed,
          # and subsequent calls to `load_hooks` silently do nothing.
          # Because of this, only one of the tests for the installation uses
          # `load_hooks`, while the rest call the `install` method directly.

          it "is added to minutely probes" do
            Appsignal::Hooks.load_hooks

            expect(Appsignal::Minutely.probes[:gvl]).to be Appsignal::Probes::GvlProbe
          end
        end
      end

      describe "#install" do
        context "with enable_gvl_global_timer" do
          it "enables the GVL global timer" do
            Appsignal.config[:enable_gvl_global_timer] = true
            expect(::GVLTools::GlobalTimer).to receive(:enable)

            described_class.new.install
          end
        end

        context "without enable_gvl_global_timer" do
          it "does not enable the GVL global timer" do
            Appsignal.config[:enable_gvl_global_timer] = false
            expect(::GVLTools::GlobalTimer).not_to receive(:enable)

            described_class.new.install
          end
        end

        context "with enable_gvl_waiting_threads" do
          it "enables the GVL waiting threads" do
            Appsignal.config[:enable_gvl_global_timer] = true
            expect(::GVLTools::WaitingThreads).to receive(:enable)

            described_class.new.install
          end
        end

        context "without enable_gvl_waiting_threads" do
          it "does not enable the GVL waiting threads" do
            Appsignal.config[:enable_gvl_waiting_threads] = false
            expect(::GVLTools::WaitingThreads).not_to receive(:enable)

            described_class.new.install
          end
        end
      end
    end
  end
end
