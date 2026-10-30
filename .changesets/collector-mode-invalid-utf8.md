---
bump: patch
type: fix
---

Handle strings that are not valid UTF-8 in collector mode

Collector mode no longer raises or drops data when it is given a string that
is not valid UTF-8. Invalid bytes are replaced with `�`.

* An error cause message, or breadcrumb metadata, with invalid bytes would
  raise a `JSON::GeneratorError` into the application.
* An invalid key or value in metric tags, log attributes or OpenTelemetry
  attributes would drop the whole export batch, or be replaced with
  `"Encoding Error"`.
* An invalid log message or logger group would drop the whole export batch.
* An invalid transaction action or namespace would drop the whole export
  batch.
* Invalid transaction metadata, tags or request headers would drop the whole
  export batch, or be replaced with `"Encoding Error"`.
* An invalid error message or backtrace, or breadcrumb category, action or
  message, would drop the whole export batch, or be replaced with
  `"Encoding Error"`.
* An invalid event name, title or body, including an SQL query, would drop
  the whole export batch, or be replaced with `"Encoding Error"`.
