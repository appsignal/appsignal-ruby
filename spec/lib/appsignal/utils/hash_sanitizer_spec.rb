describe Appsignal::Utils::HashSanitizer do
  describe ".sanitize" do
    def sanitize(value, filter_keys = [])
      described_class.sanitize(value, filter_keys)
    end

    it "accepts String values" do
      # Hashes
      expect(sanitize(:a => "abc")).to eq(:a => "abc")
      expect(sanitize("a" => "abc")).to eq("a" => "abc")
      expect(sanitize("a" => { "b" => "abc" })).to eq("a" => { "b" => "abc" })
    end

    it "accepts Symbol values" do
      expect(sanitize(:a => :abc)).to eq(:a => :abc)
      expect(sanitize("a" => :abc)).to eq("a" => :abc)
    end

    it "accepts Boolean values" do
      expect(sanitize(:a => true, :b => false)).to eq(:a => true, :b => false)
    end

    it "accepts nil values" do
      expect(sanitize(:a => nil)).to eq(:a => nil)
    end

    it "accepts number values" do
      expect(sanitize(:a => 123, :b => 123.45)).to eq(:a => 123, :b => 123.45)
    end

    it "normalizes Date objects" do
      expect(sanitize(:date => Date.new(2024, 9, 11)))
        .to eq(:date => "#<Date: 2024-09-11>")
    end

    it "normalizes unsupported objects" do
      expect(sanitize(:file => uploaded_file)[:file])
        .to include("::UploadedFile")

      expect(sanitize(:file => [:file => uploaded_file])[:file].first[:file])
        .to include("::UploadedFile")

      expect(sanitize(:object => Object.new))
        .to eq(:object => "#<Object>")
    end

    it "normalizes Time objects" do
      expect(sanitize(:time_in_utc => Time.utc(2024, 9, 12, 13, 14, 15)))
        .to eq(:time_in_utc => "#<Time: 2024-09-12T13:14:15Z>")

      expect(sanitize(:time_with_timezone => Time.new(2024, 9, 12, 13, 14, 15, "+09:00")))
        .to eq(:time_with_timezone => "#<Time: 2024-09-12T13:14:15+09:00>")
    end

    it "accepts nested Hash values" do
      expect(sanitize(:abc => 123)).to eq(:abc => 123)
      expect(sanitize("abc" => [456])).to eq("abc" => [456])
      expect(sanitize("abc" => { :a => { :b => ["c"] } }))
        .to eq("abc" => { :a => { :b => ["c"] } })
    end

    it "accepts nested Array values" do
      expect(sanitize([:abc, 123])).to eq([:abc, 123])
      expect(sanitize(["abc", [456]])).to eq(["abc", [456]])
      expect(sanitize(["abc", { :a => { :b => ["c"] } }]))
        .to eq(["abc", { :a => { :b => ["c"] } }])
    end

    it "doesn't filter non-recursive Hash values" do
      hash = { :a => :b }
      expect(sanitize([hash, hash])).to eq([{ :a => :b }, { :a => :b }])

      hash = { :a => :b }
      expect(sanitize(:x => hash, :y => hash)).to eq(:x => { :a => :b }, :y => { :a => :b })
    end

    it "filters recursive Hash values" do
      hash = { :a => :b }
      hash[:c] = hash
      expect(sanitize(hash)).to eq(:a => :b, :c => "[RECURSIVE VALUE]")

      hash = {}
      hash[:c] = { :d => hash }
      expect(sanitize(hash)).to eq(:c => { :d => "[RECURSIVE VALUE]" })
    end

    it "doesn't filters non-recursive Array values" do
      array = [:a, :b]
      expect(sanitize([array, array])).to eq([[:a, :b], [:a, :b]])
    end

    it "filters recursive Array values" do
      array = [:a, :b]
      array << array
      expect(sanitize(array)).to eq([:a, :b, "[RECURSIVE VALUE]"])

      array = [:a, :b]
      array << [array]
      expect(sanitize(array)).to eq([:a, :b, ["[RECURSIVE VALUE]"]])
    end

    it "doesn't change the original value" do
      file = uploaded_file
      expect { sanitize(:a => file) }.to_not(change { file })

      file = "text"
      expect { sanitize(:a => file) }.to_not(change { file })
    end

    describe "filter keys" do
      it "sanitizes values from string keys" do
        object = { "password" => "secret", "user_id" => 123 }
        expect(sanitize(object, ["password"]))
          .to eq("password" => "[FILTERED]", "user_id" => 123)

        object = { "user" => { "password" => "secret", "id" => 123 } }
        expect(sanitize(object, ["password"]))
          .to eq("user" => { "password" => "[FILTERED]", "id" => 123 })
      end

      it "sanitizes values from symbol keys" do
        object = { :password => "secret", :user_id => 123 }
        expect(sanitize(object, ["password"]))
          .to eq(:password => "[FILTERED]", :user_id => 123)

        object = { :user => { :password => "secret", :id => 123 } }
        expect(sanitize(object, ["password"]))
          .to eq(:user => { :password => "[FILTERED]", :id => 123 })
      end

      it "sanitizes values in a nested objects" do
        object = [
          :users => [
            { :password => "secret", :id => 123 },
            { :password => ["shhhhh"], :id => 456 },
            { :password => { :obj => "shhhhh" }, :id => 789 }
          ]
        ]
        expect(sanitize(object, ["password"])).to eq([
          :users => [
            { :password => "[FILTERED]", :id => 123 },
            { :password => "[FILTERED]", :id => 456 },
            { :password => "[FILTERED]", :id => 789 }
          ]
        ])
      end

      it "doesn't change the original value" do
        password = "secret"
        expect do
          object = { :password => password, :user_id => 123 }
          expect(sanitize(object, ["password"]))
            .to eq(:password => "[FILTERED]", :user_id => 123)
        end.to_not(change { password })
      end
    end
  end
end
