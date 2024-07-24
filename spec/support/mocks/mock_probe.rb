class MockProbe
  attr_reader :calls

  def initialize
    Appsignal::Testing.store[:mock_probe_call] = 0
    @calls = 0
  end

  def call
    Appsignal::Testing.store[:mock_probe_call] += 1
    @calls += 1
  end
end
