class MockProbe
  attr_reader :calls

  def initialize
    @calls = 0
  end

  def call
    @calls += 1
  end
end
