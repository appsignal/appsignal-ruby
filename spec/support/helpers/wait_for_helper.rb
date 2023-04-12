module WaitForHelper
  # Wait for a condition to be met
  #
  # @example
  #   # Perform threaded operation
  #   wait_for("enough probe calls") { probe.calls >= 2 }
  #   # Assert on result
  #
  # @param name [String] The name of the condition to check. Used in the
  #   error when it fails.
  # @yield Assertion to check.
  # @yieldreturn [Boolean] True/False value that indicates if the condition
  #   is met.
  # @raise [StandardError] Raises error if the condition is not met after 5
  #   seconds, 5_000 tries.
  def wait_for(name)
    max_wait = 5_000
    i = 0
    error = nil
    while i < max_wait
      begin
        result = yield
        break if result
      rescue Exception => e # rubocop:disable Lint/RescueException
        # Capture error so we know if it exited with an error
        error = e
      ensure
        i += 1
        sleep 0.001
      end
    end

    return unless i >= max_wait

    error_message =
      ("\nError: #{error.class}: #{error.message}\n#{error.backtrace.join("\n")}" if error)
    raise "Waited 5 seconds for #{name} condition, but was not met.#{error_message}"
  end
end
