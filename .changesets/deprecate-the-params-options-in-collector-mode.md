---
bump: patch
type: change
---

The `filter_parameters` and `send_params` configuration options are deprecated in collector mode. Use `filter_request_payload`, `filter_function_parameters` and `filter_request_query_parameters` to filter different kinds of parameters, and `send_request_payload`, `send_request_query_parameters` and `send_function_parameters` to choose which kinds of parameters to report.

In collector mode, each kind of parameter is now filtered and reported according to its own options, and the deprecated options' values are only used to fill in values when the new options are unset. AppSignal logs which values to set to keep reporting what it reports now.

In agent mode, `filter_parameters` and `send_params` still apply to every kind of parameter, and the new options have no effect.
