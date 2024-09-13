describe "AppSignal stop" do
  it "doesn't exit the process with a ThreadError when receiving a signal trap" do
    runner = Runner.new("stop_with_trap")
    runner.run do
      # Send a problematic signal
      # "USR1" has no special meaning for this test, it's just a signal
      Process.kill("USR1", runner.pid)
      # Give it some time to receive the signal and shut down AppSignal
      sleep(DependencyHelper.running_jruby? ? 5 : 0.5) # seconds
    end

    output = runner.output

    # Make sure the app exited properly
    expect(runner.status.exitstatus).to eq(0)

    # Assert the output has no errors
    expect(output).to_not include("ERROR: ")
    # Assert the app has started as expected
    expect(output).to include("Waiting for USR1 signal...")
    # Assert the app has received the signal
    expect(output).to include("Received USR1 signal")
    # Assert the app continued after calling Appsignal.stop
    expect(output).to include("AppSignal has shut down without raising an error")

    # Assert no errors were printed
    expect(output).to_not include("ThreadError")
    expect(output).to_not include("can't be called from trap context")
  end
end
