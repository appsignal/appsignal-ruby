require "fileutils"
require "tmpdir"

class Runner
  # Env key the Runner sets itself (see `run`). Callers can't pass it via
  # `env:` — the Runner owns the per-run working directory.
  WORKING_DIRECTORY_ENV = "APPSIGNAL_WORKING_DIRECTORY_PATH".freeze

  # Config every runner script needs, supplied as env vars so the scripts
  # don't each hardcode it; `Appsignal.start` reads it from the environment.
  # Specs assert against these values via this constant instead of repeating
  # the literals. Overridable per run by passing the same key in `env:`.
  DEFAULT_ENV = {
    "APPSIGNAL_APP_NAME" => "integration-runner",
    "APPSIGNAL_APP_ENV" => "test",
    "APPSIGNAL_PUSH_API_KEY" => "abc"
  }.freeze

  attr_reader :pid, :output, :status

  # @param env [Hash] Extra environment variables to set in the spawned
  #   child process, e.g. `"APPSIGNAL_COLLECTOR_ENDPOINT"` to run against the
  #   mock collector. Merged over {DEFAULT_ENV}; must not overlap with the
  #   Runner-managed keys.
  def initialize(name, env: {})
    if env.key?(WORKING_DIRECTORY_ENV)
      raise ArgumentError,
        "#{WORKING_DIRECTORY_ENV} is managed by Runner and can't be passed via `env:`"
    end

    @script_name = name
    @script_file = "#{@script_name}.rb"
    @env = DEFAULT_ENV.merge(env)
    @pid = nil
    @output = nil
    @status = nil
    @finish_timeout = jruby? ? 10 : 5 # seconds
    @read_timeout = 1 # seconds
    @read, @write = IO.pipe
    @has_run = false
    @finished = false
    # Per-run working directory. Passed to the subprocess via
    # `APPSIGNAL_WORKING_DIRECTORY_PATH` so runner scripts don't have to
    # manage one themselves. Created under `/tmp` rather than the default
    # `$TMPDIR` because macOS's default tmpdir lives under
    # `/var/folders/...` and the resulting agent socket path exceeds the
    # 104-char macOS unix-socket limit, which would hang
    # `Appsignal::Extension.stop`. Cleaned up after the process exits.
    @working_dir = Dir.mktmpdir("appsignal-runner-", "/tmp")
  end

  def has_run?
    @has_run
  end

  def finished?
    @finished
  end

  def run
    raise "Can't run runner more than once!" if @has_run

    @has_run = true
    executable = jruby? ? "jruby" : "ruby"
    directory = File.join(__dir__, "runners")
    @pid = spawn(
      @env.merge(WORKING_DIRECTORY_ENV => @working_dir),
      "#{executable} #{@script_file}",
      {
        [:out, :err] => @write,
        :chdir => directory
      }
    )

    yield if block_given?

    begin
      Timeout.timeout(@finish_timeout) do
        _pid, @status = Process.wait2(@pid) # Wait until the command exits
      end
    rescue Timeout::Error
      Process.kill("TERM", @pid)
      raise "ERROR: Runner '#{@script_file}' timed out after #{@finish_timeout} seconds!"
    end
    read_output
    @finished = true

    return if @status.exitstatus.zero?

    raise "Runner '#{@script_file}' exited with status #{@status.exitstatus}.\n" \
      "Output:\n#{@output}"
  ensure
    FileUtils.remove_entry(@working_dir) if @working_dir && File.exist?(@working_dir)
  end

  private

  def read_output
    Timeout.timeout(@read_timeout) do
      @write.close # Close output writer
    end

    # Read the output (STDOUT and STDERR)
    output_lines = []
    begin
      while (line = @read.readline)
        output_lines << line.rstrip
      end
    rescue EOFError
      # Nothing to read anymore. Reached end of "file".
    end
    @output = output_lines.join("\n")
  end

  def jruby?
    RUBY_PLATFORM == "java"
  end
end
