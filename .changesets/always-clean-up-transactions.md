---
bump: patch
type: fix
---

Fix an issue where a request or background job could be reported with data from
the previous one processed on the same thread.  When AppSignal's instrumentation
raised an error while starting or finishing a request or job, the next one could
be reported under the previous one's action name, with its parameters and
errors, and with a duration that was too long.  This affected the Rack, Rails,
Sinatra, Padrino, Hanami, Grape, Webmachine, Action Cable, Active Job, Sidekiq,
Delayed Job, Resque, Que and Shoryuken integrations, and `Appsignal.monitor`.

Each request and job is now reported on its own.  If such an error happens, it
is logged in the AppSignal log.  No changes to your app are needed.
