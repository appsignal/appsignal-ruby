require 'spec_helper'

describe Appsignal::EventFormatter::MongoRubyDriver::QueryFormatter do
  let(:formatter) { Appsignal::EventFormatter::MongoRubyDriver::QueryFormatter }

  describe ".format" do
    let(:strategy) { :find }
    let(:command) do
      {
        "find"   => "users",
        "filter" => {"_id" => 1}
      }
    end

    it "should apply a strategy for each key" do
      expect( formatter ).to receive(:apply_strategy)
        .with(:sanitize_document, {"_id" => 1})

      expect( formatter ).to receive(:apply_strategy)
        .with(:allow, "users")

      formatter.format(strategy, command)
    end

    context "when strategy is unkown" do
      let(:strategy) { :bananas }

      it "should return an empty hash" do
        expect( formatter.format(strategy, command) ).to eql({})
      end
    end

    context "when command is not a hash " do
      let(:command) { :bananas }

      it "should return an empty hash" do
        expect( formatter.format(strategy, command) ).to eql({})
      end
    end
  end

  describe ".apply_strategy" do
    context "when strategy is allow" do
      let(:strategy) { :allow }
      let(:value)    { {"_id" => 1} }

      it "should return the given value" do
        expect( formatter.apply_strategy(strategy, value) ).to eql(value)
      end
    end

    context "when strategy is deny" do
      let(:strategy) { :deny }
      let(:value)    { {"_id" => 1} }

      it "should return a '?'" do
        expect( formatter.apply_strategy(strategy, value) ).to eql('?')
      end
    end

    context "when strategy is deny_array" do
      let(:strategy) { :deny_array }
      let(:value)    { {"_id" => 1} }

      it "should return a sanitized array string" do
        expect( formatter.apply_strategy(strategy, value) ).to eql("[?]")
      end
    end

    context "when strategy is sanitize_document" do
      let(:strategy) { :sanitize_document }
      let(:value)    { {"_id" => 1} }

      it "should return a sanitized document" do
        expect( formatter.apply_strategy(strategy, value) ).to eql({"_id" => '?'})
      end
    end

    context "when strategy is sanitize_bulk" do
      let(:strategy) { :sanitize_bulk }
      let(:value)    { [{"q" => {"_id" => 1}, "u" => [{"foo" => "bar"}]}] }

      it "should return an array of sanitized bulk documents" do
        expect( formatter.apply_strategy(strategy, value) ).to eql([
          {"q" => {"_id" => '?'}, "u" => '[?]'}
        ])
      end
    end

    context "when strategy is missing" do
      let(:strategy) { nil }
      let(:value)    { {"_id" => 1} }

      it "should return a '?'" do
        expect( formatter.apply_strategy(strategy, value) ).to eql('?')
      end
    end
  end
end
