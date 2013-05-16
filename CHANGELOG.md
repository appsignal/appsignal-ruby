# 0.5.2

* General improvements to the rails generator
* Log to STDOUT if writing to log/appsignal.log is not possible (Heroku)
* Handle the last transactions before the rails process shuts down
* require 'erb' to enable loading of appsignal config
