if defined?(::Unicorn)
  Appsignal.logger.info('Loading Unicorn integration')

  # Make sure the last transaction in a worker gets flushed.
  #
  # We'd love to be able to hook this into Unicorn in a less
  # intrusive way, but this is the best we can do given the
  # options we have.

  class Unicorn::Worker
    alias_method :original_close, :close

    def close
      Appsignal.stop
      original_close
    end
  end
end
