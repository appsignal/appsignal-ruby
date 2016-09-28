module TransactionHelpers
  def uploaded_file
    if DependencyHelper.rails_present?
      ActionDispatch::Http::UploadedFile.new(:tempfile => '/tmp')
    else
      ::Rack::Multipart::UploadedFile.new(File.join(fixtures_dir, '/uploaded_file.txt'))
    end
  end

  def background_job_transaction(args={})
    Appsignal::Transaction.create(
      '1',
      Appsignal::Transaction::BACKGROUND_JOB,
      Appsignal::Transaction::GenericRequest.new({
        'SERVER_NAME' => 'localhost',
        'action_dispatch.routes' => 'not_available'
      }.merge(args))
    )
  end

  def http_request_transaction(args={})
    Appsignal::Transaction.create(
      '1',
      Appsignal::Transaction::HTTP_REQUEST,
      Appsignal::Transaction::GenericRequest.new({
        'SERVER_NAME' => 'localhost',
        'action_dispatch.routes' => 'not_available'
      }.merge(args))
    )
  end
end
