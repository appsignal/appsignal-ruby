module StdStreamsHelper
  # Capture STDOUT in a variable
  #
  # Usage
  #
  #     out_stream = StringIO.new
  #     capture_stdout(out_stream) { do_something }
  def capture_stdout(stdout)
    original_stdout = $stdout
    $stdout = stdout

    yield

    $stdout = original_stdout
  end

  # Capture STDOUT and STDERR in variables
  #
  # Usage
  #
  #     out_stream = StringIO.new
  #     err_stream = StringIO.new
  #     capture_std_streams(out_stream, err_stream) { do_something }
  def capture_std_streams(stdout, stderr)
    original_stdout = $stdout
    $stdout = stdout
    original_stderr = $stderr
    $stderr = stderr

    yield

    $stdout = original_stdout
    $stderr = original_stderr
  end
end
