# frozen_string_literal: true

module ModeHelpers
  # Defines the same example in both agent and collector mode. Pass an optional
  # description; it is suffixed with " in agent mode" / " in collector mode".
  #
  # Per the dual-mode start principle, each generated example starts its own
  # agent in the body: agent mode via `start_agent`, collector mode via
  # `start_collector_agent`, before running the shared block. So the block must
  # NOT start the agent itself, and any mode-dependent arrangement (e.g.
  # `set_current_transaction`, building a transaction) belongs inside the block
  # — which runs after the start — rather than in a `before` hook.
  def it_in_both_modes(description = nil, &block)
    it([description, "in agent mode"].compact.join(" "), :agent_mode) do
      start_agent(**(defined?(start_agent_args) ? start_agent_args : {}))
      instance_exec(&block)
    end
    it([description, "in collector mode"].compact.join(" "), :collector_mode) do
      start_collector_agent
      instance_exec(&block)
    end
  end
end

RSpec.configure { |config| config.extend ModeHelpers }
