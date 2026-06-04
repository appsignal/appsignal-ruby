# frozen_string_literal: true

module ModeHelpers
  # Defines the same example in both agent and collector mode. Pass an optional
  # description; it is suffixed with " in agent mode" / " in collector mode".
  def it_in_both_modes(description = nil, &block)
    it([description, "in agent mode"].compact.join(" "), :agent_mode, &block)
    it([description, "in collector mode"].compact.join(" "), :collector_mode, &block)
  end
end

RSpec.configure { |config| config.extend ModeHelpers }
