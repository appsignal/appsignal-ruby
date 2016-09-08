describe 'Appsignal::UpdateActiveSupport', :if => (
  Gem.loaded_specs['rails'] &&
  Gem.loaded_specs['rails'].version < Gem::Version.create('4.0')
) do
  require 'appsignal/update_active_support'
  let(:pattern)  { 'foo' }
  let(:delegate) { double }
  before { ActiveSupport::Notifications.subscribe(pattern, delegate) }

  it "should transfer old subscriptions to the new version" do
    expect( ActiveSupport::Notifications ).to receive(:subscribe).with(pattern, delegate)
  end

  after { Appsignal::UpdateActiveSupport.run }
end
