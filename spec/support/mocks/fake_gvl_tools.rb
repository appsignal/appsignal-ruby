module FakeGVLTools
  def self.reset
    self::GlobalTimer.monotonic_time = 0
    self::WaitingThreads.count = 0
  end

  module GlobalTimer
    @monotonic_time = 0

    class << self
      attr_accessor :monotonic_time
    end
  end

  module WaitingThreads
    @count = 0
    @enabled = false

    class << self
      attr_accessor :count
      attr_writer :enabled

      def enabled?
        @enabled
      end
    end
  end
end
