describe Appsignal::SampleData do
  let(:data) { described_class.new(:data_key) }

  describe "#add" do
    it "sets the given value" do
      logs =
        capture_logs do
          data.add(:key1 => "value 1")
        end

      expect(data.value).to eq(:key1 => "value 1")

      expect(logs).to_not contains_log(
        :error,
        "Sample data 'data_key': Unsupported data type 'NilClass' received: nil"
      )
    end

    it "adds the given value with the block being leading" do
      data.add(:key1 => "value 1") { { :key2 => "value 2" } }

      expect(data.value).to eq(:key2 => "value 2")
    end

    it "doesn't add nil to the data" do
      logs =
        capture_logs do
          data.add([1])
          data.add(nil)
          data.add { nil }
          data.add([2, 3])
        end

      expect(data.value).to eq([1, 2, 3])
      expect(logs).to contains_log(
        :error,
        "Sample data 'data_key': Unsupported data type 'NilClass' received: nil"
      )
      expect(logs).to_not contains_log(:warn, "The sample data 'data_key' changed type")
    end

    it "merges multiple values" do
      data.add(:key1 => "value 1")
      data.add(:key2 => "value 2")

      expect(data.value).to eq(:key1 => "value 1", :key2 => "value 2")
    end

    it "merges only root level Hash keys" do
      data.add(:key => { :abc => "value" })
      data.add(:key => { :def => "value" })

      expect(data.value).to eq(:key => { :def => "value" })
    end

    it "merges values from arguments and blocks" do
      data.add(:key1 => "value 1")
      data.add { { :key2 => "value 2" } }
      data.add(:key3 => "value 3")

      expect(data.value).to eq(:key1 => "value 1", :key2 => "value 2", :key3 => "value 3")
    end

    it "merges array values" do
      data.add([:first_arg])
      data.add { [:from_block] }
      data.add([:second_arg])

      expect(data.value).to eq([:first_arg, :from_block, :second_arg])
    end

    it "overwrites the value if the new value is of a different type" do
      data.add(:key1 => "value 1")
      expect(data.value).to eq(:key1 => "value 1")

      data.add(["abc"])
      expect(data.value).to eq(["abc"])

      logs = capture_logs { data.value }
      expect(logs).to contains_log(
        :warn,
        "The sample data 'data_key' changed type from 'Hash' to 'Array'."
      )
    end

    it "ignores invalid values" do
      logs = capture_logs { data.add("string") }
      expect(data.value).to be_nil
      expect(logs).to contains_log(
        :error,
        "Sample data 'data_key': Unsupported data type 'String' received: \"string\""
      )

      set = Set.new
      set.add("abc")
      logs = capture_logs { data.add(set) }
      expect(data.value).to be_nil
      expect(logs).to contains_log(
        :error,
        "Sample data 'data_key': Unsupported data type 'Set' received: #<Set: {\"abc\"}>"
      )

      instance = Class.new
      logs = capture_logs { data.add(instance) }
      expect(data.value).to be_nil
      expect(logs).to contains_log(
        :error,
        "Sample data 'data_key': Unsupported data type 'Class' received: #<Class:"
      )
    end

    context "with a type specified" do
      it "only accepts values of Hash type" do
        data = described_class.new(:data_key, Hash)

        data.add(:key1 => "value 1")
        data.add(["abc"])
        data.add { { :key2 => "value 2" } }
        data.add { ["def"] }
        data.add(:key3 => "value 3")

        expect(data.value).to eq(:key1 => "value 1", :key2 => "value 2", :key3 => "value 3")
      end

      it "only accepts values of Array type" do
        data = described_class.new(:data_key, Array)

        data.add(:key1 => "value 1")
        data.add(["abc"])
        data.add { { :key2 => "value 2" } }
        data.add { ["def"] }
        data.add(:key3 => "value 3")

        expect(data.value).to eq(["abc", "def"])
      end
    end
  end

  describe "#value" do
    it "caches the block value after calling it once" do
      Appsignal::Testing.store[:block_call] = 0
      data.add do
        Appsignal::Testing.store[:block_call] += 1
        { :key => "value" }
      end

      expect(data.value).to eq(:key => "value")
      data.value

      expect(Appsignal::Testing.store[:block_call]).to eq(1)
    end
  end

  describe "#value?" do
    it "returns true when value is set" do
      data.add(["abc"])
      expect(data.value?).to be_truthy
    end

    it "returns true when value is set with a block" do
      data.add { ["abc"] }
      expect(data.value?).to be_truthy
    end

    it "returns false when the value is not set" do
      expect(data.value?).to be_falsey
    end
  end

  describe "#set_empty_value!" do
    it "clears the set values" do
      data.add(["abc"])
      data.add(["def"])
      data.set_empty_value!

      expect(data.value).to be_nil
    end

    it "allows values to be added afterwards" do
      data.add(["abc"])
      data.set_empty_value!

      expect(data.value).to be_nil

      data.add(["def"])
      expect(data.value).to eq(["def"])
    end
  end

  describe "#cleared?" do
    it "returns false if not cleared" do
      expect(data.empty?).to be(false)
    end

    it "returns true if cleared" do
      data.set_empty_value!

      expect(data.empty?).to be(true)
    end

    it "returns false if cleared and then new values were added" do
      data.set_empty_value!
      data.add(["abc"])

      expect(data.empty?).to be(false)
    end
  end

  describe "#duplicate" do
    it "duplicates the internal Hash state without modifying the original" do
      data = described_class.new(:my_key, Hash)
      data.add(:abc => :value)

      duplicate = data.dup
      duplicate.add(:def => :value)

      expect(data.value).to eq(:abc => :value)
      expect(duplicate.value).to eq(:abc => :value, :def => :value)

      expect(duplicate.instance_variable_get(:@key)).to eq(:my_key)
      expect(duplicate.instance_variable_get(:@accepted_type)).to eq(Hash)
    end

    it "duplicates the internal Array state without modifying the original" do
      data = described_class.new(:my_key, Array)
      data.add([:abc])

      duplicate = data.dup
      duplicate.add([:def])

      expect(data.value).to eq([:abc])
      expect(duplicate.value).to eq([:abc, :def])

      expect(duplicate.instance_variable_get(:@key)).to eq(:my_key)
      expect(duplicate.instance_variable_get(:@accepted_type)).to eq(Array)
    end
  end
end
