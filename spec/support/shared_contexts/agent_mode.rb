# frozen_string_literal: true

RSpec.shared_context "agent mode", :agent_mode do
  before { start_agent }
end

RSpec.configure do |config|
  config.include_context "agent mode", :agent_mode
end
