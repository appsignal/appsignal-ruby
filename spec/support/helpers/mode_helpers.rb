# frozen_string_literal: true

module ModeHelpers
  def it_in_both_modes(&block)
    it("in agent mode", :agent_mode, &block)
    it("in collector mode", :collector_mode, &block)
  end
end

RSpec.configure { |config| config.extend ModeHelpers }
