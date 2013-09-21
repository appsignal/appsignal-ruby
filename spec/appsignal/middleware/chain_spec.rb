require 'spec_helper'

describe Appsignal::Middleware do
  let(:chain_klass) { Appsignal::Middleware::Chain }
  let(:entry_klass) { Appsignal::Middleware::Entry }
  let(:chain) { chain_klass.new }
  let(:entry) { entry_klass.new(object, {:foo => :bar}) }

  describe Appsignal::Middleware::Chain do
    let(:object) { double(:object) }
    let(:other_object) { double(:other_object) }

    describe "#initialize" do
      it "yields itself when passing a block" do
        chain_klass.new { |o| o.should be_instance_of chain_klass }
      end
    end

    describe "#remove" do
      subject { chain.remove(object) }
      before { chain.add(other_object) }

      context "when it doesn't find the object" do
        specify { expect { subject }.to_not raise_error }
      end

      context "when it finds the object" do
        before { chain.add(object) }

        specify { expect { subject }.to change(chain.entries, :count).by(-1) }
      end
    end

    describe "#add" do
      subject { chain.add(object) }

      context "adding a new object" do
        specify { expect { subject }.to change(chain.entries, :count).by(1) }
      end

      context "trying to add a duplicate (even with different arguments)" do
        before { chain.add(object, :some_arguments) }

        specify { expect { subject }.to_not change(chain.entries, :count).by(1) }
      end
    end

    context "with a chain holding three items" do
      subject { chain.entries.map(&:klass) }
      before { [:first, :second, :third].each { |o| chain.add(o) } }

      describe "#insert_before" do

        context "before the second" do
          before { chain.insert_before(:second, :object) }

          it { should == [:first, :object, :second, :third] }
        end

        context "before the first" do
          before { chain.insert_before(:first, :object) }

          it { should == [:object, :first, :second, :third] }
        end
      end

      describe "#insert_after" do

        context "after the second" do
          before { chain.insert_after(:second, :object) }

          it { should == [:first, :second, :object, :third] }
        end

        context "after the third" do
          before { chain.insert_after(:third, :object) }

          it { should == [:first, :second, :third, :object] }
        end
      end

      describe "#exists?" do
        subject { chain.exists?(object) }

        context "when it is in the chain" do
          let(:object) { :first }

          it { should be_true }
        end

        context "when it is not" do
          let(:object) { :unknown }

          it { should be_false }
        end
      end

      describe "#retrieve" do
        specify { chain.entries.each { |o| o.should_receive(:make_new) } }

        after { chain.retrieve }
      end

      describe "#clear" do
        before { chain.clear }
        subject { chain.entries }

        it { should be_empty }
      end
    end

    describe "#invoke" do
      let(:recorder) { [] }
      subject { chain.invoke(:unsused) }
      before(:all) do
        TestInvoker1 = Struct.new(:id, :recorder) do
          def call(event)
            recorder << "Before#{id}"
            yield
            recorder << "After#{id}"
          end
        end
        TestInvoker3 = Class.new(TestInvoker1)
      end

      context "all yielding entries" do
        before do
          TestInvoker2 = Class.new(TestInvoker1)

          chain.add(TestInvoker1, 1, recorder)
          chain.add(TestInvoker2, 2, recorder)
          chain.add(TestInvoker3, 3, recorder)
        end

        it { should == %w(Before1 Before2 Before3 After3 After2 After1) }
      end

      context "a non yielding entry" do
        before do
          TestBlocker = Struct.new(:recorder) do
            def call(event)
              recorder << 'End-of-the-line!'
            end
          end

          chain.add(TestInvoker1, 1, recorder)
          chain.add(TestBlocker, recorder)
          chain.add(TestInvoker3, 3, recorder)
        end

        it { should == %w(Before1 End-of-the-line! After1) }
      end
    end
  end

  describe Appsignal::Middleware::Entry do

    describe "#make_new" do
      let(:object) { double }
      subject { entry.make_new }

      it "initializes the passed object" do
        object.should_receive(:new)
        subject
      end
    end
  end
end
