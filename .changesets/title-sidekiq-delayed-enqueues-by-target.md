---
bump: patch
type: change
---

Title `enqueue.sidekiq` events for Sidekiq delayed extension jobs after the
delayed target and method, such as `enqueue MyClass.my_method job`, instead of
the internal wrapper class. This matches the name the job is given when it
later performs, so the enqueue and perform of the same job read the same name.
