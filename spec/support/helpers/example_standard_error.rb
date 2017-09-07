# This ExampleStandardError is used for throwing errors in specs that are
# allowed or expected.
#
# For example, this error can be thrown to raise an exception in AppSignal's
# run, which should stop the program and the appsignal gem, but not crash the
# test suite.
#
# There's also {ExampleException}, use this when you need to test against
# Exception-level Ruby exceptions.
#
# @see ExampleException
class ExampleStandardError < StandardError
end
