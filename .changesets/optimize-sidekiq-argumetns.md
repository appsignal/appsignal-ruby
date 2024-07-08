---
bump: patch
type: change
---

Optimize Sidekiq job arguments being recorded. Job arguments are only fetched and set when we sample the job transaction, which should decrease our overhead for all jobs we don't sample.
