---
bump: patch
type: fix
---

Handle strings that are not valid UTF-8 in collector mode

Collector mode no longer raises or drops data when it is given a string that
is not valid UTF-8. Invalid bytes are replaced with `�`.

* An error cause message, or breadcrumb metadata, with invalid bytes would
  raise a `JSON::GeneratorError` into the application.
