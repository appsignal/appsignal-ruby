---
bump: patch
type: fix
---

Read an array configuration option written as a null in `config/appsignal.yml` as the empty list it means. Options such as `filter_parameters` and `ignore_actions` raised a `NoMethodError` when AppSignal started, and `filter_metadata` and `filter_session_data` raised one while a transaction was sampled.
