---
bump: "patch"
type: "add"
---

Add an option to not start AppSignal on config file errors. When the `config/appsignal.yml` file raises an error (due to ERB syntax issues or ERB errors), it will currently ignore the config file and try to make a configuration work from the other config sources (default, auto detection and system environment variables). This can cause unexpected behavior, because the config from the config file is not part of the loaded config.

In future versions of the Ruby gem, AppSignal will not start when the config file contains an error. To opt-in to this new behavior, set the `APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR` system environment variable to either `1` or `true`.
