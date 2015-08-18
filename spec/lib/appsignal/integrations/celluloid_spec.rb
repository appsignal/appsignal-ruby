require 'spec_helper'

describe "Celluloid integration" do
  let(:file) { File.expand_path('lib/appsignal/integrations/celluloid.rb') }

  context "with celluloid" do
    before(:all) do
      module Celluloid
        def self.shutdown
        end
      end
    end

    before do
      load file
    end

    specify { expect(Appsignal).to receive(:stop_extension) }

    specify { expect(Celluloid).to receive(:shutdown_without_appsignal) }
    after do
      Celluloid.shutdown
    end
  end

  context "without celluloid" do
    before(:all) { Object.send(:remove_const, :Celluloid) }

    specify { expect { ::Celluloid }.to raise_error(NameError) }
    specify { expect { load file }.to_not raise_error }
  end
end
