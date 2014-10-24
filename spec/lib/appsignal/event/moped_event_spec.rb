require 'spec_helper'

describe Appsignal::Event::MopedEvent do
  let(:event) do
    Appsignal::Event::MopedEvent.new('query.moped', 1, 2, 123, {})
  end

  describe "#transform_payload" do
    before { event.stub(:payload_from_op => {'foo' => 'bar'}) }

    it "should map the operations to a normalized payload" do
      expect( event.transform_payload(:ops => [{}]) ).to eq(
        :ops => [{'foo' => 'bar'}]
      )
    end
  end

  describe "#payload_from_op" do
    context "Moped::Protocol::Query" do
      let(:payload) do
        double(
          :full_collection_name => 'database.collection',
          :selector             => {'_id' => 'abc'},
          :class                => double(:to_s => 'Moped::Protocol::Command')
        )
      end

      it "should transform the payload" do
        expect( event.payload_from_op(payload) ).to eq(
          :type     => "Command",
          :database => "database.collection",
          :selector => {"_id" => "?"}
        )
      end
    end

    context "Moped::Protocol::Query" do
      let(:payload) do
        double(
          :full_collection_name => 'database.collection',
          :selector             => {'_id' => 'abc'},
          :flags                => [],
          :limit                => 0,
          :skip                 => 0,
          :fields               => nil,
          :class                => double(:to_s => 'Moped::Protocol::Query')
        )
      end

      it "should transform the payload" do
        expect( event.payload_from_op(payload) ).to eq(
          :type     => "Query",
          :database => "database.collection",
          :selector => {"_id" => "?"},
          :flags    => [],
          :limit    => 0,
          :skip     => 0,
          :fields   => nil,
        )
      end
    end

    context "Moped::Protocol::Delete" do
      let(:payload) do
        double(
          :full_collection_name => 'database.collection',
          :selector             => {'_id' => 'abc'},
          :flags                => [],
          :class                => double(:to_s => 'Moped::Protocol::Delete')
        )
      end

      it "should transform the payload" do
        expect( event.payload_from_op(payload) ).to eq(
          :type     => "Delete",
          :database => "database.collection",
          :selector => {"_id" => "?"},
          :flags    => []
        )
      end
    end

    context "Moped::Protocol::Insert" do
      let(:payload) do
        double(
          :full_collection_name => 'database.collection',
          :flags                => [],
          :documents            => [{'_id' => 'abc'}, {'_id' => 'def'}],
          :class                => double(:to_s => 'Moped::Protocol::Insert')
        )
      end

      it "should transform the payload" do
        expect( event.payload_from_op(payload) ).to eq(
          :type      => "Insert",
          :database  => "database.collection",
          :flags     => [],
          :documents => [{"_id" => "?"}, {"_id" => "?"}]
        )
      end
    end

    context "Moped::Protocol::Update" do
      let(:payload) do
        double(
          :full_collection_name => 'database.collection',
          :selector             => {'_id' => 'abc'},
          :update               => {'name' => 'James Bond'},
          :flags                => [],
          :class                => double(:to_s => 'Moped::Protocol::Update')
        )
      end

      it "should transform the payload" do
        expect( event.payload_from_op(payload) ).to eq(
          :type     => "Update",
          :database => "database.collection",
          :selector => {"_id" => "?"},
          :update   => {"name" => "?"},
          :flags    => []
        )
      end
    end

    context "Moped::Protocol::KillCursors" do
      let(:payload) do
        double(
          :number_of_cursor_ids => 2,
          :class                => double(:to_s => 'Moped::Protocol::KillCursors')
        )
      end

      it "should transform the payload" do
        expect( event.payload_from_op(payload) ).to eq(
          :type                 => "KillCursors",
          :number_of_cursor_ids => 2
        )
      end
    end

    context "Moped::Protocol::Other" do
      let(:payload) do
        double(
          :full_collection_name => 'database.collection',
          :class                => double(:to_s => 'Moped::Protocol::Other')
        )
      end

      it "should transform the payload" do
        expect( event.payload_from_op(payload) ).to eq(
          :type     => "Other",
          :database => "database.collection"
        )
      end
    end
  end

  describe "#sanitize" do
    context "when params is a hash" do
      let(:params) { {'foo' => 'bar'} }

      it "should sanitize all hash values with a questionmark" do
        expect( event.sanitize(params) ).to eq('foo' => '?')
      end
    end

    context "when params is an array of hashes" do
      let(:params) { [{'foo' => 'bar'}] }

      it "should sanitize all hash values with a questionmark" do
        expect( event.sanitize(params) ).to eq([{'foo' => '?'}])
      end
    end

    context "when params is an array of strings " do
      let(:params) { ['foo', 'bar'] }

      it "should sanitize all hash values with a single questionmark" do
        expect( event.sanitize(params) ).to eq(['?'])
      end
    end
    context "when params is a string" do
      let(:params) { 'bar'}

      it "should sanitize all hash values with a questionmark" do
        expect( event.sanitize(params) ).to eq('?')
      end
    end
  end
end
