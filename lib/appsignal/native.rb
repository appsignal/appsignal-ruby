require 'ffi'

module Appsignal
  module Native
   extend FFI::Library

    def self.libappsignal_path
      extension = if Gem::Platform.local.os == 'darwin'
        'dylib'
      else
        'so'
      end
      File.expand_path("../../../ext/libappsignal.#{extension}", __FILE__)
    end

    ffi_lib libappsignal_path

    attach_function(
      :start,
      :appsignal_start,
      [],
      :bool
    )

    attach_function(
      :start_transaction,
      :appsignal_start_transaction,
      [:string],
      :void
    )

    attach_function(
      :start_event,
      :appsignal_start_event,
      [:string],
      :void
    )

    attach_function(
      :finish_event,
      :appsignal_finish_event,
      [:string, :string, :string, :string],
      :void
    )

    attach_function(
      :set_exception_for_transaction,
      :appsignal_set_exception_for_transaction,
      [:string, :string, :string],
      :void
    )

    attach_function(
      :set_transaction_metadata,
      :appsignal_set_transaction_metadata,
      [:string, :string, :string, :int64],
      :void
    )

    attach_function(
      :finish_transaction,
      :appsignal_finish_transaction,
      [:string],
      :void
    )

    attach_function(
      :transmit_marker,
      :appsignal_transmit_marker,
      [:string, :string],
      :int32
    )

    attach_function(
      :check_push_api_auth,
      :appsignal_check_push_api_auth,
      [],
      :int32
    )
  end
end
