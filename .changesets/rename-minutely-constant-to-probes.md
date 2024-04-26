---
bump: "patch"
type: "change"
---

Rename the Minutely constant to Probes so that the API is the same between AppSignal integrations. If your apps calls `Appsignal::Minutely`, please update it to `Appsignal::Probes`. Other than the name change, the minutely probes API remains the same. If your app calls `Appsignal::Minutely` after this upgrade without the name change, the gem will print a deprecation warning for each time the `Appsignal::Minutely` is called.
