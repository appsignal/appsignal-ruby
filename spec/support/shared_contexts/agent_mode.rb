# frozen_string_literal: true

RSpec.shared_context "agent mode", :agent_mode do
  # Dual-mode start principle (see also collector_mode.rb): mode setup is a
  # global, and having both an automatic `before` here AND ad-hoc `start_agent`
  # calls elsewhere fight over it (last writer wins, order is fragile). Going
  # forward, prefer starting the agent explicitly in the example body. A
  # describe tagged `:manual_start` opts out of this automatic start; its
  # `it "in agent mode"` calls `start_agent` itself before `perform`.
  #
  # Examples can define a `start_agent_args` `let` to pass `:env`/`:options` to
  # `start_agent` (the collector-mode context accepts the same hook and also
  # injects the `collector_endpoint`). Guarded with `defined?` rather than a
  # default `let` here, because an included shared context's `let` would take
  # precedence over the example group's own `let` override.
  before do |example|
    next if example.metadata[:manual_start]

    start_agent(**(defined?(start_agent_args) ? start_agent_args : {}))
  end

  # Make completed transactions readable via `to_h` so agent-mode tests can
  # assert on `include_event` / `include_tags` etc. after the transaction
  # has been completed. Harmless when the example doesn't complete the
  # transaction inside the body -- it just sets and unsets a flag.
  around { |example| keep_transactions { example.run } }
end

RSpec.configure do |config|
  config.include_context "agent mode", :agent_mode
end
