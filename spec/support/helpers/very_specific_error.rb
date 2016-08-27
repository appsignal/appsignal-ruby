# This VerySpecificError is used for throwing errors in specs that are allowed
# or expected.
#
# For example, this error can be thrown to raise an exception in AppSignal's
# run, which should stop the program and the appsignal gem, but not crash the
# test suite.
class VerySpecificError < RuntimeError
end
