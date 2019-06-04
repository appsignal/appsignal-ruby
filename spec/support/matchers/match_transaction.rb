RSpec::Matchers.define :match_transaction do |expected|
  match do |actual|
    @actual = actual.to_h
    @expected = {
      "action" => kind_of(String),
      "error" => be_nil | be_kind_of(String),
      "events" => kind_of(Array),
      "id" => kind_of(String),
      "metadata" => kind_of(Hash),
      "namespace" => kind_of(String),
      "sample_data" => kind_of(Hash),
      "timestamp" => kind_of(Integer)
    }.merge(expected)
    expect(@actual).to match(@expected)
  end

  diffable
end
