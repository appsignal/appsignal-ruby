describe Appsignal::EventFormatter::ElasticSearch::SearchFormatter do
  let(:klass)     { Appsignal::EventFormatter::ElasticSearch::SearchFormatter }
  let(:formatter) { klass.new }

  it "should register search.elasticsearch" do
    expect(
      Appsignal::EventFormatter.registered?("search.elasticsearch", klass)
    ).to be_truthy
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
      expect(formatter.format(payload)).to eql([
        "Search: User",
        "{:index=>\"users\", :type=>\"user\", :q=>\"?\"}"
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
