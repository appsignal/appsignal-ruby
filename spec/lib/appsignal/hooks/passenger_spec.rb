describe Appsignal::Hooks::PassengerHook do
  context "with passenger" do
    before(:all) do
      module PhusionPassenger
      end
    end
    after(:all) { Object.send(:remove_const, :PhusionPassenger) }

    its(:dependencies_present?) { should be_true }

    it "adds behavior to stopping_worker_process and starting_worker_process" do
      PhusionPassenger.should_receive(:on_event).with(:starting_worker_process)
      PhusionPassenger.should_receive(:on_event).with(:stopping_worker_process)

      Appsignal::Hooks::PassengerHook.new.install
    end
  end

  context "without passenger" do
    its(:dependencies_present?) { should be_false }
  end
end
