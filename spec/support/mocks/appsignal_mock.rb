class AppsignalMock
  attr_reader :gauges

  def initialize(hostname: nil)
    @hostname = hostname
    @gauges = []
  end

  def config
    options = {}
    options[:hostname] = @hostname if @hostname
    ConfigHelpers.build_config(:options => options)
  end

  def set_gauge(*args)
    @gauges << args
  end
end
