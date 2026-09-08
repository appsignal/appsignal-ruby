#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks that every example defined in the suite is actually run by some
# combination in the build matrix.
#
# An example inside a false dependency guard is never defined, so it appears in
# no run and in no report. That cannot be detected from inside RSpec, because
# there is nothing to compare against: the guard removed the example before
# RSpec ever saw it. So this reads the source with Prism to learn what exists,
# and compares that against the example lists every CI job uploads.
#
# Usage: bundle exec ruby script/audit_spec_coverage.rb <artifacts-directory>
#
# The directory is expected to hold one subdirectory per CI job, named after the
# job, each containing that job's `examples-*.json`.

require "json"
require "prism"
require "yaml"

WORKFLOW = ".github/workflows/ci.yml"

# Example-defining methods, from rspec-core's `example_group.rb`. RSpec records
# each of these at the line where its block opens.
RSPEC_EXAMPLE_METHODS = %w[
  example it specify
  focus fexample fit fspecify
  xexample xit xspecify
  skip pending
].freeze

# This suite's own example-defining helpers, mapped to how many examples one
# call defines. They pass `:caller` so that RSpec records the call site rather
# than the helper, and Ruby's `caller` reports the line where the call starts,
# so they anchor differently from the methods above.
#
# The count is matched with `===`, so a range works wherever an exact number
# does. Only reach for one when a call site legitimately reports more, which
# happens when one line is used by more than one inclusion: a loop around the
# call, or the call living in a shared example group included from several
# places. Note what widening costs. `2..` also accepts two inclusions that each
# ran one of their two examples, which is the very thing this count checks for.
CALLER_ANCHORED_METHODS = { "it_in_both_modes" => 2 }.freeze

# A built-in example method defines one example per call, but one call can be
# reported many times over when it sits in a shared example group, so the only
# safe expectation is that it ran at least once.
BUILT_IN_EXAMPLE_COUNT = (1..).freeze

# Methods that never run an example body, so a pending result from them is
# deliberate rather than a condition that is met everywhere. RSpec gives each a
# fixed pending message.
DELIBERATE_SKIP_MESSAGE =
  /\ATemporarily skipped with x(it|example|specify|describe|context)\z/.freeze

# Each definition is a path and the lines RSpec might record it at. A built-in
# example method can be recorded at either of two lines when its description
# wraps, because the call and its block then start on different lines and which
# one RSpec uses depends on the Ruby version: 3.1 to 3.3 report the call, while
# 3.4 and later report the block. A helper that passes `:caller` has only one
# possible line on every version, so listing a second one for it would treat a
# line RSpec can never report as accounted for.
#
# An example method called inside a `def` is a helper defining examples for its
# callers, and the call sites are what we check, so those are not counted.
def example_definitions_in(path)
  result = Prism.parse_file(path)
  # Prism returns a tree even when it could not parse the file, so without this
  # a file it choked on would contribute no definitions at all and the audit
  # would quietly conclude that fewer examples exist than really do.
  abort "Could not parse #{path}: #{result.errors.first.message}" if result.failure?

  found = []
  collect_examples(result.value, found, path)
  found
end

def collect_examples(node, found, path, in_method: false)
  return unless node.is_a?(Prism::Node)

  in_method = true if node.is_a?(Prism::DefNode)

  if node.is_a?(Prism::CallNode) && node.block && node.receiver.nil? && !in_method
    name = node.name.to_s
    if RSPEC_EXAMPLE_METHODS.include?(name)
      lines = [node.location.start_line, node.block.location.start_line].uniq
      found << { :path => path, :lines => lines, :expected => BUILT_IN_EXAMPLE_COUNT }
    elsif CALLER_ANCHORED_METHODS.key?(name)
      found << {
        :path => path,
        :lines => [node.location.start_line],
        :expected => CALLER_ANCHORED_METHODS.fetch(name)
      }
    end
  end

  node.compact_child_nodes.each do |child|
    collect_examples(child, found, path, :in_method => in_method)
  end
end

def defined_examples
  paths = Dir.glob("spec/**/*.rb").reject do |path|
    path.start_with?("spec/integration/diagnose/")
  end
  paths.flat_map { |path| example_definitions_in(path) }.uniq
end

# Every job that runs tests, and the example lists it is expected to upload.
# Read from the generated workflow rather than from `build_matrix.yml`, because
# the workflow is the literal list of jobs and CI already checks that the two
# agree.
def expected_jobs
  workflow = YAML.safe_load_file(WORKFLOW, :aliases => true)
  workflow.fetch("jobs").each_with_object({}) do |(name, job), expected|
    next unless job.dig("env", "BUNDLE_GEMFILE")

    steps = job["steps"] || []
    runs_failure_leg = steps.any? { |step| step["run"].to_s.include?("rake test:failure") }

    lists = ["examples-test.json"]
    lists << "examples-failure.json" if runs_failure_leg
    expected[name] = lists
  end
end

def read_reported_examples(directory)
  # Keyed by file and description rather than by line, because the line an
  # example is reported at varies by Ruby version and a per-line key would split
  # one example's results into two partial sets.
  reported = {}
  descriptions = {}
  incomplete = []

  Dir.glob(File.join(directory, "*")).sort.each do |job_directory|
    next unless File.directory?(job_directory)

    job = File.basename(job_directory)
    Dir.glob(File.join(job_directory, "*.json")).sort.each do |file|
      examples = parse_example_list(file)
      if examples.nil? || examples.empty?
        incomplete << "#{job}/#{File.basename(file)}"
        next
      end

      examples.each do |example|
        path = example["file_path"].sub(%r{\A\./}, "")
        line = example["line_number"]
        description = example["full_description"]
        ((descriptions[path] ||= {})[line] ||= []) << description
        key = [path, description]
        entry = reported[key] ||= { :path => path, :line => line, :results => [] }
        entry[:results] << [example["status"], example["pending_message"]]
      end
    end
  end

  descriptions.each_value { |lines| lines.each_value(&:uniq!) }
  [reported, descriptions, incomplete]
end

def parse_example_list(file)
  JSON.parse(File.read(file))["examples"]
rescue JSON::ParserError
  nil
end

def source_line(path, line)
  File.readlines(path)[line - 1].to_s.strip
rescue StandardError
  ""
end

def report(title, explanation, entries)
  puts
  puts "#{title} (#{entries.length})"
  puts explanation
  puts
  entries.each { |line| puts "  #{line}" }
end

directory = ARGV[0]
abort "Usage: bundle exec ruby #{$PROGRAM_NAME} <artifacts-directory>" if directory.nil?
abort "No such directory: #{directory}" unless File.directory?(directory)

defined = defined_examples
reported, reported_descriptions, incomplete = read_reported_examples(directory)

# A reported line is accounted for when some definition in that file could have
# been recorded at it.
known_lines = {}
defined.each do |definition|
  (known_lines[definition[:path]] ||= []).concat(definition[:lines])
end
reported_lines = reported_descriptions.transform_values(&:keys)

# How many distinct examples the matrix reported for one definition, counted
# across both of the lines it could have been recorded at.
ran_count = lambda do |definition|
  lines = reported_descriptions[definition[:path]] || {}
  definition[:lines].flat_map { |line| lines[line] || [] }.uniq.length
end

failures = []

# A missing or empty list means a job did not finish, and its examples would
# then look unreachable. The JSON formatter writes its document only when the
# run ends, so a crashed job leaves nothing at all behind.
missing = expected_jobs.flat_map do |job, lists|
  lists.reject { |list| File.file?(File.join(directory, job, list)) }
    .map { |list| "#{job}/#{list}" }
end

if missing.any? || incomplete.any?
  entries = missing.map { |list| "#{list} (missing)" } +
    incomplete.map { |list| "#{list} (no examples)" }
  report(
    "Incomplete example lists",
    "These jobs uploaded no usable list, so the audit cannot draw any conclusion.\n" \
      "Re-run once the matrix is green.",
    entries
  )
  failures << :incomplete
end

unparsed = reported_lines.flat_map do |path, lines|
  (lines - (known_lines[path] || [])).map { |line| [path, line] }
end
if unparsed.any?
  report(
    "Reported by RSpec but not found in the source",
    "The parser in this script does not know about a helper that defines examples.\n" \
      "Add it to RSPEC_EXAMPLE_METHODS or CALLER_ANCHORED_METHODS. Until then the\n" \
      "audit undercounts and its other findings cannot be trusted.",
    unparsed.sort.map { |path, line| "#{path}:#{line}" }
  )
  failures << :unparsed
end

if failures.empty?
  counted = defined.map { |definition| [definition, ran_count.call(definition)] }
    # rubocop:disable Style/CaseEquality
    .reject { |definition, count| definition[:expected] === count }
  # rubocop:enable Style/CaseEquality
  never_run, partly_run = counted.partition { |_, count| count.zero? }

  if never_run.any?
    report(
      "Defined but never run",
      "No combination in the build matrix runs these examples. Either a dependency\n" \
        "guard cannot be true anywhere, or the matrix is missing a combination.",
      never_run.map do |definition, _|
        path = definition[:path]
        line = definition[:lines].first
        "#{path}:#{line}  #{source_line(path, line)}"
      end.sort
    )
    failures << :never_run
  end

  if partly_run.any?
    report(
      "Ran a different number of examples than the source defines",
      "A helper such as `it_in_both_modes` defines more than one example per call,\n" \
        "and they share a line, so one of them never running is invisible to the\n" \
        "check above. Running fewer than expected means a combination that should\n" \
        "cover one of them does not. Running more means the line is used by more\n" \
        "than one inclusion, and the count in CALLER_ANCHORED_METHODS needs to be a\n" \
        "range. Read the note there first, because widening it gives something up.",
      partly_run.map do |definition, count|
        path = definition[:path]
        line = definition[:lines].first
        "#{path}:#{line}  expected #{definition[:expected]}, ran #{count}"
      end.sort
    )
    failures << :count_mismatch
  end

  always_pending = reported.each_value.select do |entry|
    entry[:results].all? do |status, message|
      status == "pending" && !DELIBERATE_SKIP_MESSAGE.match?(message.to_s)
    end
  end

  if always_pending.any?
    report(
      "Pending everywhere",
      "These examples are skipped in every combination that runs them, so they never\n" \
        "assert anything. Deliberate markers such as `xit` are not reported here.",
      always_pending.map do |entry|
        message = entry[:results].map(&:last).compact.uniq.join(", ")
        "#{entry[:path]}:#{entry[:line]}  #{message}"
      end.sort
    )
    failures << :always_pending
  end
end

puts
if failures.empty?
  puts "All #{defined.length} defined examples run in at least one combination."
  exit 0
end

puts "Spec coverage audit failed: #{failures.join(", ")}."
exit 1
