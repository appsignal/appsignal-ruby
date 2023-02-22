module TransactionHelpers
  def uploaded_file
    if DependencyHelper.rails_present?
      ActionDispatch::Http::UploadedFile.new(:tempfile => "/tmp")
    else
      ::Rack::Multipart::UploadedFile.new(File.join(fixtures_dir, "/uploaded_file.txt"))
    end
  end

  def background_job_transaction(args = {})
    Appsignal::Transaction.new(
      "1",
      Appsignal::Transaction::BACKGROUND_JOB,
      Appsignal::Transaction::GenericRequest.new({
        "SERVER_NAME" => "localhost",
        "action_dispatch.routes" => "not_available"
      }.merge(args))
    )
  end

  def http_request_transaction(args = {})
    Appsignal::Transaction.new(
      "1",
      Appsignal::Transaction::HTTP_REQUEST,
      Appsignal::Transaction::GenericRequest.new({
        "SERVER_NAME" => "localhost",
        "action_dispatch.routes" => "not_available"
      }.merge(args))
    )
  end

  # Returns the all {Appsignal::Transaction} objects created during this test
  # run so far.
  #
  # @return [Array<Appsignal::Transaction>]
  def created_transactions
    Appsignal::Testing.transactions
  end

  # Returns the last created {Appsignal::Transaction}.
  #
  # @return [Appsignal::Transaction]
  def last_transaction
    created_transactions.last
  end

  # Set current transaction manually.
  # Cleared by {clear_current_transaction!}
  #
  # When a block is given, the current transaction is automatically unset after
  # the block.
  def set_current_transaction(transaction) # rubocop:disable Naming/AccessorMethodName
    Thread.current[:appsignal_transaction] = transaction
    yield if block_given?
  ensure
    clear_current_transaction! if block_given?
  end

  # Use when {Appsignal::Transaction.clear_current_transaction!} is stubbed to
  # clear the current transaction on the current thread.
  def clear_current_transaction!
    Thread.current[:appsignal_transaction] = nil
  end

  # Set the current for the duration of the given block.
  #
  # Helper for {set_current_transaction} and {clear_current_transaction!}
  def with_current_transaction(transaction)
    set_current_transaction transaction
    yield
  ensure
    clear_current_transaction!
  end

  # Track the AppSignal transaction JSON when a transaction gets completed
  # ({Appsignal::Transaction.complete}).
  #
  # It will also add sample data to the transaction when it gets completed.
  # This can be disabled by setting the `sample` option to `false`.
  #
  # It will be tracked for every transaction that is started inside the
  # `keep_transactions` block.
  #
  # @example Keep a transaction while also adding sample data
  #   keep_transactions do
  #     transaction = Appsignal::Transaction.new(...)
  #     transaction.complete
  #     transaction.to_h # => Hash with transaction data before it was completed
  #   end
  #
  # @example Keep a transaction without adding sample data
  #   keep_transactions :sample => false do
  #     transaction = Appsignal::Transaction.new(...)
  #     transaction.complete
  #     transaction.to_h
  #     # => Hash with transaction data before it was completed with an empty
  #     #    Hash for the `sample_data` key.
  #   end
  #
  # @yield block to perform while the transactions are tracked.
  # @param options [Hash]
  # @option options [Boolean] :sample Whether or not to sample transactions.
  # @return [Object] returns the block return value.
  def keep_transactions(options = {})
    Appsignal::Testing.keep_transactions = true
    Appsignal::Testing.sample_transactions = options.fetch(:sample, true)
    yield
  ensure
    Appsignal::Testing.keep_transactions = nil
    Appsignal::Testing.sample_transactions = nil
  end
end
