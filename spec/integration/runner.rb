class Runner
  attr_reader :pid, :output, :status

  def initialize(name)
    @script_name = name
    @script_file = "#{@script_name}.rb"
    @pid = nil
    @output = nil
    @status = nil
    @post_spawn_wait = jruby? ? 10 : 0.5 # seconds
    @finish_timeout = jruby? ? 10 : 5 # seconds
    @read_timeout = 1 # seconds
    @read, @write = IO.pipe
    @has_run = false
    @finished = false
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
      "#{executable} #{@script_file}",
      {
        [:out, :err] => @write,
        :chdir => directory
      }
    )
    sleep @post_spawn_wait # Let the app boot

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
  end

  private

  def read_output
    Timeout.timeout(@read_timeout) do
      @write.close # Close output writer
    end

    # Read the output (STDOUT and STDERR)
    output_lines = []
    begin
      while line = @read.readline # rubocop:disable Lint/AssignmentInCondition
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
