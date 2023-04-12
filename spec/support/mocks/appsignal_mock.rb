class AppsignalMock
  attr_reader :gauges

  def initialize(hostname: nil)
    @hostname = hostname
    @gauges = []
  end

  def config
    ConfigHelpers.project_fixture_config.tap do |conf|
      conf[:hostname] = @hostname if @hostname
    end
  end

  def set_gauge(*args)
    @gauges << args
  end
end
