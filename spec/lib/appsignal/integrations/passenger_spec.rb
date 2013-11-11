require 'spec_helper'

describe "Passenger integration" do
  let(:file) { File.expand_path('lib/appsignal/integrations/passenger.rb') }
  before(:all) { module PhusionPassenger ; end }

  it "adds behavior to stopping_worker_process and starting_worker_process" do
    PhusionPassenger.should_receive(:on_event).with(:starting_worker_process)
    PhusionPassenger.should_receive(:on_event).with(:stopping_worker_process)
    load file
  end

  context "without passenger" do
    before(:all) { Object.send(:remove_const, :PhusionPassenger) }

    specify { expect { PhusionPassenger }.to raise_error(NameError) }
    specify { expect { load file }.to_not raise_error }
  end
end
