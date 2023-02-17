module FakeGVLTools
  def self.reset
    self::GlobalTimer.enabled = false
    self::GlobalTimer.monotonic_time = 0
    self::WaitingThreads.enabled = false
    self::WaitingThreads.count = 0
  end

  module GlobalTimer
    @enabled = false
    @monotonic_time = 0

    class << self
      attr_writer :enabled
      attr_accessor :monotonic_time

      def enabled?
        @enabled
      end
    end
  end

  module WaitingThreads
    @enabled = false
    @count = 0

    class << self
      attr_writer :enabled
      attr_accessor :count

      def enabled?
        @enabled
      end
    end
  end
end
