module TimeHelpers
  def advance_frozen_time(time, addition)
    Time.at(time.to_f + addition).tap do |new_time|
      Timecop.freeze(new_time)
    end
  end
end
