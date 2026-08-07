describe Appsignal::EventFormatter::ElasticSearch::SearchFormatter do
  let(:klass)     { Appsignal::EventFormatter::ElasticSearch::SearchFormatter }
  let(:formatter) { klass.new }

  it "should register search.elasticsearch" do
    expect(
      Appsignal::EventFormatter.registered?("search.elasticsearch", klass)
    ).to be_truthy
  end

  describe "#opentelemetry_kind" do
    subject { formatter.opentelemetry_kind }

    it { is_expected.to eq :client }
  end

  describe "#opentelemetry_attributes" do
    subject { formatter.opentelemetry_attributes(payload) }

    context "with a search naming one index" do
      let(:payload) { { :search => { :index => "users" } } }

      it "names the index it searched" do
        is_expected.to eq(
          "db.system.name" => "elasticsearch",
          "db.operation.name" => "search",
          "db.collection.name" => "users"
        )
      end
    end

    context "with a search naming more than one index" do
      let(:payload) { { :search => { :index => ["users", "accounts"] } } }

      it "names no index rather than a value that is not one" do
        is_expected.to eq(
          "db.system.name" => "elasticsearch",
          "db.operation.name" => "search"
        )
      end
    end

    context "without a search" do
      let(:payload) { {} }

      it "still describes the span as an Elasticsearch search" do
        is_expected.to eq(
          "db.system.name" => "elasticsearch",
          "db.operation.name" => "search"
        )
      end
    end
  end

  describe "#format" do
    let(:payload) do
      {
        :name => "Search",
        :klass => "User",
        :search => { :index => "users", :type => "user", :q => "John Doe" }
      }
    end

    it "should return a payload with name and sanitized body" do
      query =
        if DependencyHelper.ruby_3_4_or_newer?
          "{index: \"users\", type: \"user\", q: \"?\"}"
        else
          "{:index=>\"users\", :type=>\"user\", :q=>\"?\"}"
        end
      expect(formatter.format(payload)).to eql([
        "Search: User",
        query
      ])
    end
  end

  describe "#sanitized_search" do
    let(:search) do
      {
        :index => "users",
        :type => "user",
        :q => "John Doe",
        :other => "Other"
      }
    end

    it "should sanitize non-allowlisted params" do
      expect(
        formatter.sanitized_search(search)
      ).to eql(:index => "users", :type => "user", :q => "?", :other => "?")
    end

    it "should return nil string when search is nil" do
      expect(formatter.sanitized_search(nil)).to be_nil
    end

    it "should return nil string when search is not a hash" do
      expect(formatter.sanitized_search([])).to be_nil
    end
  end
end
