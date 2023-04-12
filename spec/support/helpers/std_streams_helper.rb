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

  # Silence the STDOUT.
  #
  # Ignore the STDOUT and don't print it in the test suite's STDOUT.
  #
  # If an error is found the output the output is raised as an error, failing
  # the spec. Warnings and other AppSignal messages are ignored.
  #
  # @example
  #   silence { do_something }
  #   # Does nothing
  #
  #   silence { puts "ERROR!" }
  #   # => Error found in silenced output:
  #   # ERROR!
  #
  # @example Ignore certain errors
  #   silence(:allowed => ["my error"]) { puts "my error!" }
  #   # Does nothing
  #
  #   silence { puts "my error!" }
  #   # => Error found in silenced output:
  #   # my error!
  def silence(options = {}, &block)
    stream = Tempfile.new(SecureRandom.uuid)
    capture_std_streams(stream, stream, &block)
  ensure
    output = filter_allowed_errors(stream.read, options.fetch(:allowed, []))
    raise "Error found in silenced output:\n#{output}" if output =~ /(ERR|Error|error)/
  end

  def filter_allowed_errors(output, allowed_errors)
    output.lines.reject do |line|
      reject = false
      allowed_errors.each do |error|
        if line.include?(error)
          reject = true
          break
        end
      end
      reject
    end.join(",")
  end
end
