module SystemHelpers
  def recognize_as_heroku
    ENV["DYNO"] = "dyno1"
    value = yield
    ENV.delete "DYNO"
    value
  end
end
