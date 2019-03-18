describe Appsignal::EventFormatter::Moped::QueryFormatter do
  let(:klass) { Appsignal::EventFormatter::Moped::QueryFormatter }
  let(:formatter) { klass.new }

  it "should register query.moped" do
    expect(Appsignal::EventFormatter.registered?("query.moped", klass)).to be_truthy
  end

  describe "#format" do
    let(:payload) { { :ops => [op] } }
    subject { formatter.format(payload) }

    context "without ops in the payload" do
      let(:payload) { {} }

      it { is_expected.to be_nil }
    end

    context "when ops is nil in the payload" do
      let(:payload) { { :ops => nil } }

      it { is_expected.to be_nil }
    end

    context "Moped::Protocol::Command" do
      let(:op) do
        double(
          :full_collection_name => "database.collection",
          :selector             => { "query" => { "_id" => "abc" } },
          :class                => double(:to_s => "Moped::Protocol::Command")
        )
      end

      it { is_expected.to eq ["Command", '{:database=>"database.collection", :selector=>{"query"=>"?"}}'] }
    end

    context "Moped::Protocol::Query" do
      let(:op) do
        double(
          :full_collection_name => "database.collection",
          :selector             => { "_id" => "abc" },
          :flags                => [],
          :limit                => 0,
          :skip                 => 0,
          :fields               => nil,
          :class                => double(:to_s => "Moped::Protocol::Query")
        )
      end

      it { is_expected.to eq ["Query", '{:database=>"database.collection", :selector=>{"_id"=>"?"}, :flags=>[], :limit=>0, :skip=>0, :fields=>nil}'] }
    end

    context "Moped::Protocol::Delete" do
      let(:op) do
        double(
          :full_collection_name => "database.collection",
          :selector             => { "_id" => "abc" },
          :flags                => [],
          :class                => double(:to_s => "Moped::Protocol::Delete")
        )
      end

      it { is_expected.to eq ["Delete", '{:database=>"database.collection", :selector=>{"_id"=>"?"}, :flags=>[]}'] }
    end

    context "Moped::Protocol::Insert" do
      let(:op) do
        double(
          :full_collection_name => "database.collection",
          :flags                => [],
          :documents            => [
            { "_id" => "abc", "events" => { "foo" => [{ "bar" => "baz" }] } },
            { "_id" => "def", "events" => { "foo" => [{ "baz" => "bar" }] } }
          ],
          :class                => double(:to_s => "Moped::Protocol::Insert")
        )
      end

      it { is_expected.to eq ["Insert", '{:database=>"database.collection", :documents=>{"_id"=>"?", "events"=>"?"}, :count=>2, :flags=>[]}'] }
    end

    context "Moped::Protocol::Update" do
      let(:op) do
        double(
          :full_collection_name => "database.collection",
          :selector             => { "_id" => "abc" },
          :update               => { "user.name" => "James Bond" },
          :flags                => [],
          :class                => double(:to_s => "Moped::Protocol::Update")
        )
      end

      it { is_expected.to eq ["Update", '{:database=>"database.collection", :selector=>{"_id"=>"?"}, :update=>{"user.?"=>"?"}, :flags=>[]}'] }
    end

    context "Moped::Protocol::KillCursors" do
      let(:op) do
        double(
          :number_of_cursor_ids => 2,
          :class                => double(:to_s => "Moped::Protocol::KillCursors")
        )
      end

      it { is_expected.to eq ["KillCursors", "{:number_of_cursor_ids=>2}"] }
    end

    context "Moped::Protocol::Other" do
      let(:op) do
        double(
          :full_collection_name => "database.collection",
          :class                => double(:to_s => "Moped::Protocol::Other")
        )
      end

      it { is_expected.to eq ["Other", '{:database=>"database.collection"}'] }
    end
  end
end
