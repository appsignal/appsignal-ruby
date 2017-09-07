# This ExampleException is used for throwing Exceptions in specs that are
# allowed or expected.
#
# For example, this error can be thrown to raise an exception in AppSignal's
# run, which should stop the program and the appsignal gem, but not crash the
# test suite.
#
# There's also {ExampleStandardError}, use this when you need to test against
# StandardError-level Ruby exceptions.
#
# @see ExampleStandardError
class ExampleException < Exception # rubocop:disable Lint/InheritException
end
