describe Appsignal::Utils::BoundedCache do
  let(:cache) { described_class.new }

  it "derives a value once per key" do
    calls = 0
    2.times do
      cache.fetch("sql.active_record") do
        calls += 1
        "scope"
      end
    end

    expect(cache.fetch("sql.active_record") { raise "not called" }).to eq("scope")
    expect(calls).to eq(1)
  end

  it "caches a nil value" do
    scope = nil
    cache.fetch("event") { scope }

    expect(cache.fetch("event") { raise "not called" }).to be_nil
  end

  it "starts over once full, so later keys are still cached" do
    described_class::MAX_SIZE.times { |index| cache.fetch(index) { index } }
    cache.fetch("late") { "value" }

    expect(cache.fetch("late") { raise "not called" }).to eq("value")
    expect(cache.fetch(0) { "derived again" }).to eq("derived again")
  end
end
