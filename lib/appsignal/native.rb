require 'ffi'

module Appsignal
  module Native
   extend FFI::Library

    ffi_lib File.expand_path(File.join(File.dirname(__FILE__), '../../ext/libappsignal.dylib'))

    attach_function(
      :start,
      :appsignal_start,
      [:string, :string, :string, :string, :string],
      :void
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
      [:string, :string, :string, :int],
      :void
    )

    attach_function(
      :finish_transaction,
      :appsignal_finish_transaction,
      [:string],
      :void
    )
  end
end
