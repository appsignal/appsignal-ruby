# frozen_string_literal: true

RSpec.shared_context "agent mode", :agent_mode do
  # Examples can define a `start_agent_args` `let` to pass `:env`/`:options` to
  # `start_agent` (the collector-mode context accepts the same hook and also
  # injects the `collector_endpoint`). Guarded with `defined?` rather than a
  # default `let` here, because an included shared context's `let` would take
  # precedence over the example group's own `let` override.
  before { start_agent(**(defined?(start_agent_args) ? start_agent_args : {})) }

  # Make completed transactions readable via `to_h` so agent-mode tests can
  # assert on `include_event` / `include_tags` etc. after the transaction
  # has been completed. Harmless when the example doesn't complete the
  # transaction inside the body -- it just sets and unsets a flag.
  around { |example| keep_transactions { example.run } }
end

RSpec.configure do |config|
  config.include_context "agent mode", :agent_mode
end
