# AppSignal apm for Ruby - Renuo version

Read the [original README](https://github.com/appsignal/appsignal-ruby) to get the details about this gem.
Here we will list only the diffrerences with the original gem.

## Sampling

You can sample your requests by setting the ENV variable `APPSIGNAL_SAMPLING_RATE`. A value of `1` (the default) means
that all requests will be recorded in Appsignal.
A value of `0.5` means that only 50% of the requests will be recorded.
A value of `0.01` means that only 1% of the requests will be recorded.

This does not include errors. If an error occurs during a transaction, it will always be recorded.

> ⚠️ This will mess up your statistics on Appsignal of course.


