---
bump: patch
type: fix
---

Fix Que jobs on Que 0.x being enqueued with an extra `job_options` argument. The
enqueue instrumentation added in version 4.9.0 always passed a `job_options`
keyword argument on to Que, even when the caller had not passed one itself. Que
0.x reads its scheduling options from a trailing hash instead of a `job_options`
keyword argument, so it did not recognise that keyword and stored it as an extra
job argument. The job then failed when it ran, because it was given one argument
more than it expected.

Que 1 and Que 2 were not affected, because both accept a `job_options` keyword
argument and neither turns it into a job argument.

The plugin now forwards the enqueue call to Que exactly as it was made. Que 0.x
is also part of the test matrix from now on, so this is covered by tests.
