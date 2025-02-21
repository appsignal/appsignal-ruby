---
bump: minor
type: add
---

Add a helper to create custom markers from the Ruby gem.

Create a custom marker (a little icon shown in the graph timeline on AppSignal.com) to mark events on the timeline.

Create a marker with all the available options:

```ruby
Appsignal::CustomMarker.report(
  # The icon shown on the timeline
  :icon => "🎉",
  # The message shown on hover
  :message => "Migration completed",
  # Any time object or a string with a ISO8601 valid time is accepted
  :created_at => Time.now
)
```

Create a marker with just a message:

```ruby
Appsignal::CustomMarker.report(
  :message => "Migration completed",
)
```

_The default icon is the 🚀 icon. The default time is the time the request is received by our servers._
