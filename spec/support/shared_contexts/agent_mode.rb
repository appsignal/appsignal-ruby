# frozen_string_literal: true

RSpec.shared_context "agent mode", :agent_mode do
  # Dual-mode start principle (see also collector_mode.rb): mode is global
  # state, so the agent is NOT started in a `before` here -- that fought with
  # ad-hoc `start_agent` calls elsewhere (last writer wins, order is fragile).
  # Each `:agent_mode` example starts the agent itself in its body with
  # `start_agent` (the `it_in_both_modes` helper does this for its shared body).
  # This context just makes completed transactions readable via `to_h` so the
  # agent-mode matchers can assert on `include_event` / `include_tags` etc.
  # after the transaction has been completed. Harmless when the example doesn't
  # complete the transaction inside the body -- it just sets and unsets a flag.
  around { |example| keep_transactions { example.run } }
end

RSpec.configure do |config|
  config.include_context "agent mode", :agent_mode
end
