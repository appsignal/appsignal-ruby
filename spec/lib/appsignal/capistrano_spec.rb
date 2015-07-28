require 'spec_helper'

if capistrano_present?

  describe "Capistrano integration loader" do
    let(:file) { File.expand_path('lib/appsignal/capistrano.rb') }

    context "with Capistrano 3", :if => capistrano3_present? do
      before do
        require 'capistrano/all'
        require 'capistrano/deploy'
        load file
      end

      it "should load the cap file" do
        expect( Rake::Task.task_defined?('appsignal:deploy') ).to be_true
      end
    end

    context "with Capistrano 2", :if => capistrano2_present? do
      let(:loaded_files) do
        $LOADED_FEATURES.map do |loaded_feature|
          File.basename(loaded_feature)
        end
      end

      before do
        require 'capistrano'
        load file
      end

      it "should load the capistrano 2 tasks" do
        expect( loaded_files ).to include('capistrano_2_tasks.rb')
      end
    end
  end
end
