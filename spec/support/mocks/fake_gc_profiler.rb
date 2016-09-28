class FakeGCProfiler
  attr_accessor :total_time
  attr_writer :clear_delay

  def initialize(total_time = 0)
    @total_time = total_time
  end

  def clear
    sleep clear_delay
    @total_time = 0
  end

  private

  def clear_delay
    @clear_delay ||= 0
  end
end
