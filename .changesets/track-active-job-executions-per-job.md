---
bump: "patch"
type: "add"
---

Track Active Job executions per job. When a job is retried the "executions" metadata for Active Job jobs goes up by one for every retry. We now track this as the `executions` tag on the job sample.
