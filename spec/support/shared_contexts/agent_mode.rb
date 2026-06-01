# frozen_string_literal: true

RSpec.shared_context "agent mode", :agent_mode do
  before { start_agent }

  # Make completed transactions readable via `to_h` so agent-mode tests can
  # assert on `include_event` / `include_tags` etc. after the transaction
  # has been completed. Harmless when the example doesn't complete the
  # transaction inside the body -- it just sets and unsets a flag.
  around { |example| keep_transactions { example.run } }
end

RSpec.configure do |config|
  config.include_context "agent mode", :agent_mode
end
