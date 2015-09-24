require 'spec_helper'

describe Appsignal::EventFormatter::Moped::QueryFormatter do
  let(:klass) { Appsignal::EventFormatter::Moped::QueryFormatter }
  let(:formatter) { klass.new }

  it "should register query.moped" do
    Appsignal::EventFormatter.registered?('query.moped', klass).should be_true
  end

  describe "#format" do
    let(:payload) { {:ops => [op]} }
    subject { formatter.format(payload) }

    context "without ops in the payload" do
      let(:payload) { {} }

      it { should be_nil }
    end

    context "Moped::Protocol::Command" do
      let(:op) do
        double(
          :full_collection_name => 'database.collection',
          :selector             => {'_id' => 'abc'},
          :class                => double(:to_s => 'Moped::Protocol::Command')
        )
      end

      it { should == ['Command', '{:database=>"database.collection", :selector=>{"_id"=>"?"}}'] }
    end

    context "Moped::Protocol::Query" do
      let(:op) do
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

      it { should == ['Query', '{:database=>"database.collection", :selector=>{"_id"=>"?"}, :flags=>[], :limit=>0, :skip=>0, :fields=>nil}'] }
    end

    context "Moped::Protocol::Delete" do
      let(:op) do
        double(
          :full_collection_name => 'database.collection',
          :selector             => {'_id' => 'abc'},
          :flags                => [],
          :class                => double(:to_s => 'Moped::Protocol::Delete')
        )
      end

      it { should == ['Delete', '{:database=>"database.collection", :selector=>{"_id"=>"?"}, :flags=>[]}'] }
    end

    context "Moped::Protocol::Insert" do
      let(:op) do
        double(
          :full_collection_name => 'database.collection',
          :flags                => [],
          :documents            => [
            {'_id' => 'abc', 'events' => {'foo' => [{'bar' => 'baz'}]}},
            {'_id' => 'def', 'events' => {'foo' => [{'baz' => 'bar'}]}}
          ],
          :class                => double(:to_s => 'Moped::Protocol::Insert')
        )
      end

      it { should == ['Insert', '{:database=>"database.collection", :documents=>{"_id"=>"?", "events"=>"?"}, :count=>2, :flags=>[]}'] }
    end

    context "Moped::Protocol::Update" do
      let(:op) do
        double(
          :full_collection_name => 'database.collection',
          :selector             => {'_id' => 'abc'},
          :update               => {'name' => 'James Bond'},
          :flags                => [],
          :class                => double(:to_s => 'Moped::Protocol::Update')
        )
      end

      it { should == ['Update', '{:database=>"database.collection", :selector=>{"_id"=>"?"}, :update=>{"name"=>"?"}, :flags=>[]}'] }
    end

    context "Moped::Protocol::KillCursors" do
      let(:op) do
        double(
          :number_of_cursor_ids => 2,
          :class                => double(:to_s => 'Moped::Protocol::KillCursors')
        )
      end

      it { should == ['KillCursors', '{:number_of_cursor_ids=>2}'] }
    end

    context "Moped::Protocol::Other" do
      let(:op) do
        double(
          :full_collection_name => 'database.collection',
          :class                => double(:to_s => 'Moped::Protocol::Other')
        )
      end

      it { should == ['Other', '{:database=>"database.collection"}'] }
    end
  end

  describe "#sanitize" do
    context "when params is a hash" do
      let(:params) { {'foo' => 'bar'} }

      it "should sanitize all hash values with a questionmark" do
        expect( formatter.send(:sanitize, params) ).to eq('foo' => '?')
      end
    end

    context "when params is an array of hashes" do
      let(:params) { [{'foo' => 'bar'}] }

      it "should sanitize all hash values with a questionmark" do
        expect( formatter.send(:sanitize, params) ).to eq([{'foo' => '?'}])
      end
    end

    context "when params is an array of strings " do
      let(:params) { ['foo', 'bar'] }

      it "should sanitize all hash values with a single questionmark" do
        expect( formatter.send(:sanitize, params) ).to eq(['?'])
      end
    end
    context "when params is a string" do
      let(:params) { 'bar'}

      it "should sanitize all hash values with a questionmark" do
        expect( formatter.send(:sanitize, params) ).to eq('?')
      end
    end
  end
end
