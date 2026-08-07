---
bump: patch
type: change
---

Report Active Job's and Faraday's own instrumentation events again when
AppSignal's instrumentation for those libraries is turned off.

AppSignal records an enqueued Active Job, and a Faraday request, as events of
its own. Active Job and Faraday each report the same work through
ActiveSupport::Notifications as well, so since version 4.9.0 AppSignal has
ignored those notifications to avoid recording the same work twice.

It ignored them even when there was nothing to record twice. An application
that sets `instrument_active_job` or `instrument_faraday` to `false` got no
event for that work at all, not even the one the library reported itself. Those
notifications are now ignored only while AppSignal is recording the work
itself.
