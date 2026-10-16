---
bump: patch
type: fix
---

Improve JSON generation resiliency

Adds failsafe in multiple scenarios:

* Nested structures with more than 100 levels would crash.  We now limit the
  depth level to 100 and set the content of the last level to the string
  `"[MAX DEPTH REACHED]”`.  We log an error when this happens.
* Objects that do not answer to to_s would crash.  Now, a default string is
  placed in its place `"[UNSERIALIZABLE VALUE]"`.  We log an error when this
  happens.
* Binary strings are converted to UTF-8, invalid bytes are replaced with `�`.
* The presence of consts `Float::NAN`, `Float::INFINITY` would crash.  We now
  convert them to the strings `"NaN"`, `"Infinity"` and `"-Infinity"`.

Unknown crash causes are now logged.
