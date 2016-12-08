module StdStreamsHelper
  def std_stream
    Tempfile.new SecureRandom.uuid
  end

  # Capture STDOUT in a variable
  #
  # Given tempfiles are rewinded and unlinked after yield, so no cleanup
  # required. You can read from the stream using `stdout.read`.
  #
  # Usage
  #
  #     out_stream = Tempfile.new
  #     capture_stdout(out_stream) { do_something }
  def capture_stdout(stdout)
    original_stdout = $stdout.dup
    $stdout.reopen stdout

    yield
  ensure
    $stdout.reopen original_stdout
    stdout.rewind
    stdout.unlink
  end

  # Capture STDOUT and STDERR in variables
  #
  # Given tempfiles are rewinded and unlinked after yield, so no cleanup
  # required. You can read from the stream using `stdout.read`.
  #
  # Usage
  #
  #     out_stream = Tempfile.new
  #     err_stream = Tempfile.new
  #     capture_std_streams(out_stream, err_stream) { do_something }
  def capture_std_streams(stdout, stderr)
    original_stdout = $stdout.dup
    $stdout.reopen stdout
    original_stderr = $stderr.dup
    $stderr.reopen stderr

    yield
  ensure
    $stdout.reopen original_stdout
    $stderr.reopen original_stderr
    stdout.rewind
    stdout.unlink
    stderr.rewind
    stderr.unlink
  end
end
