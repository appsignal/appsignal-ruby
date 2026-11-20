---
bump: patch
type: fix
---

Fix reporting strings that are not valid UTF-8. In collector mode, a batch of
traces, metrics or logs that contains such a string is now sent, where before
the whole batch was lost. In agent mode, a request header name or an error
cause's backtrace that contains one is now reported without raising an error in
the application. In Rails apps, an error whose backtrace contains one is now
reported in both modes. Bytes that are not valid UTF-8 are replaced with `�`,
and strings in another encoding, such as ISO-8859-1, are converted to UTF-8.
