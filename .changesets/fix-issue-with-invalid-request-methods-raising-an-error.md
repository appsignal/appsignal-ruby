---
bump: patch
type: fix
---

Fix an issue with invalid request methods raising an error in the GenericInstrumentation middleware when using a request class that throws an error when calling the `request_method` method, like `ActionDispatch::Request`.
