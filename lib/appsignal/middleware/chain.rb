module Appsignal
  # Middleware is code configured to run before/after a message is processed.
  # It is patterned after Rack middleware.
  #
  # @example To add middleware:
  #
  #   Appsignal.post_processing_middleware do |chain|
  #     chain.add MyPostProcessingHook
  #   end
  #
  # @example To insert immediately preceding another entry:
  #
  #   Appsignal.post_process_middleware do |chain|
  #     chain.insert_before ActiveRecord, MyPostProcessingHook
  #   end
  #
  # @example To insert immediately after another entry:
  #
  #   Appsignal.post_process_middleware do |chain|
  #     chain.insert_after ActiveRecord, MyPostProcessingHook
  #   end
  #
  # @example This is an example of a minimal middleware class:
  #
  #   class MySHook
  #     def call(transaction)
  #       puts "Before post processing"
  #       yield
  #       puts "After post processing"
  #     end
  #   end
  #
  module Middleware
    class Chain
      attr_reader :entries

      def initialize
        @entries = []
        yield self if block_given?
      end

      def remove(klass)
        entries.delete_if { |entry| entry.klass == klass }
      end

      def add(klass, *args)
        entries << Entry.new(klass, *args) unless exists?(klass)
      end

      def insert_before(oldklass, newklass, *args)
        i = entries.index { |entry| entry.klass == newklass }
        new_entry = i.nil? ? Entry.new(newklass, *args) : entries.delete_at(i)
        i = entries.find_index { |entry| entry.klass == oldklass } || 0
        entries.insert(i, new_entry)
      end

      def insert_after(oldklass, newklass, *args)
        i = entries.index { |entry| entry.klass == newklass }
        new_entry = i.nil? ? Entry.new(newklass, *args) : entries.delete_at(i)
        i = entries.find_index { |entry| entry.klass == oldklass } || entries.count - 1
        entries.insert(i+1, new_entry)
      end

      def exists?(klass)
        entries.any? { |entry| entry.klass == klass }
      end

      def retrieve
        @retrieve ||= entries.map(&:make_new)
      end

      def clear
        entries.clear
      end

      def invoke(*args)
        chain = retrieve.dup
        traverse_chain = lambda do
          unless chain.empty?
            chain.shift.call(*args, &traverse_chain)
          end
        end
        traverse_chain.call
      end
    end

    class Entry
      attr_reader :klass
      def initialize(klass, *args)
        @klass = klass
        @args  = args
      end

      def make_new
        @klass.new(*@args)
      end
    end
  end
end
