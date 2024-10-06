describe Appsignal::EventFormatter::ActiveSupport::CacheFormatter do
  let(:klass)     { described_class }
  let(:formatter) { klass.new }

  it "should register cache_delete.active_support" do
    expect(Appsignal::EventFormatter.registered?("cache_delete.active_support", klass)).to be_truthy
  end

  it "should register cache_delete_multi.active_support" do
    expect(Appsignal::EventFormatter.registered?("cache_delete_multi.active_support",
      klass)).to be_truthy
  end

  it "should register cache_exist?.active_support" do
    expect(Appsignal::EventFormatter.registered?("cache_exist?.active_support", klass)).to be_truthy
  end

  it "should register cache_fetch.active_support" do
    expect(Appsignal::EventFormatter.registered?("cache_fetch.active_support", klass)).to be_truthy
  end

  it "should register cache_read.active_support" do
    expect(Appsignal::EventFormatter.registered?("cache_read.active_support", klass)).to be_truthy
  end

  it "should register cache_read_multi.active_support" do
    expect(Appsignal::EventFormatter.registered?("cache_read_multi.active_support",
      klass)).to be_truthy
  end

  it "should register cache_write.active_support" do
    expect(Appsignal::EventFormatter.registered?("cache_write.active_support", klass)).to be_truthy
  end

  it "should register cache_write_multi.active_support" do
    expect(Appsignal::EventFormatter.registered?("cache_write.active_support", klass)).to be_truthy
  end

  describe "#format" do
    context "when a single key event is given" do
      let(:payload) do
        {
          :key => "cache_key",
          :store => "ActiveSupport::Cache::RedisCacheStore",
          :namespace => "my_rails_app",
          :expires_in => 1
        }
      end

      subject { formatter.format(payload) }

      it { is_expected.to eq ["cache_key", nil] }
    end

    context "when a multi key event is given" do
      let(:payload) do
        {
          :key => ["cache_key", :another_key],
          :store => "ActiveSupport::Cache::RedisCacheStore",
          :namespace => "my_rails_app",
          :expires_in => 1
        }
      end

      subject { formatter.format(payload) }

      it { is_expected.to eq ["another_key, cache_key", nil] }
    end

    context "when the write_multi event is given" do
      let(:payload) do
        {
          :key => { "cache_key" => "value", :another_key => "another_value" },
          :store => "ActiveSupport::Cache::RedisCacheStore",
          :namespace => "my_rails_app",
          :expires_in => 1
        }
      end

      subject { formatter.format(payload) }

      it { is_expected.to eq ["another_key, cache_key", nil] }
    end
  end
end
