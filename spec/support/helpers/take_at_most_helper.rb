module TakeAtMostHelper
  # Assert that it takes at most a certain amount of time to run a block.
  #
  # @example
  #  # Assert that it takes at most 1 second to run the block
  #  take_at_most(1) { sleep 0.5 }
  #
  # @param time [Integer, Float] The maximum amount of time the block is allowed to
  #  run in seconds.
  # @yield Block to run.
  # @raise [StandardError] Raises error if the block takes longer than the
  #  specified time to run.
  def take_at_most(time)
    start = Time.now
    yield
    elapsed = Time.now - start
    return if elapsed <= time

    raise "Expected block to take at most #{time} seconds, but took #{elapsed}"
  end
end
