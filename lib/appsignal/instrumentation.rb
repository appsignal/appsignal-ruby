require 'appsignal/instrumentation/mongo'
require 'appsignal/instrumentation/tire'

Appsignal::MongoInstrumentation.setup(Appsignal.logger)
Appsignal::TireInstrumentation.setup(Appsignal.logger)
