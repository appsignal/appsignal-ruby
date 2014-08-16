class Appsignal::Event < ActiveSupport::Notifications:: Event

  def sanitize!
    @payload = Appsignal::ParamsSanitizer.sanitize(@payload)
  end

  def truncate!
    @payload = {}
  end

end
