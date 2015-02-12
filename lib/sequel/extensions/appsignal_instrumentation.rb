# Register the extension with Sequel. This being a module, the extension
# will replace it's defined methods within Sequel::Database directly.
#
# Reason why this file exists where it does, is because when you call #extension
# on a Sequel::Database instance, it will automatically load this.
Sequel::Database.register_extension(
  :appsignal_instrumentation,
  Appsignal::Integrations::Sequel
)

