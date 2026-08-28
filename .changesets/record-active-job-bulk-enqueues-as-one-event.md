---
bump: patch
type: fix
---

Record a single event for a bulk enqueue of Active Job jobs. Before this change,
enqueuing jobs with `ActiveJob.perform_all_later` would record an event for the
batch and, if the adapter was instrumented with AppSignal, another event for each
job in it. A job that slices a large collection and enqueues it in batches was
therefore reported with an event per job enqueued, where before version 4.9.0 it
had one event per batch.

A bulk enqueue is now recorded as a single `enqueue_all.active_job` event, named
after the job class when every job in the batch shares one.
