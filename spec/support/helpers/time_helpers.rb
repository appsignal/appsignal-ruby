module TimeHelpers
  def fixed_time
    @fixed_time ||= Time.utc(2014, 1, 15, 11, 0, 0).to_f
  end

  def advance_frozen_time(time, addition)
    Time.at(time.to_f + addition).tap do |new_time|
      Timecop.freeze(new_time)
    end
  end
end
