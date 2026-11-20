---
bump: patch
type: fix
---

Fix reporting strings that are not valid UTF-8.  In collector mode, a batch of
traces, metrics or logs that contains said string prevented the batch from being
sent.  In agent mode, a request header name or an error backtrace that contains
said string would raise an error in the application.

Now, string bytes that are not valid UTF-8 are replaced with `�`, and strings in
another encoding are converted to UTF-8, thus preventing the data loss and the
error raising mentioned above.
