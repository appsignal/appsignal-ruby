class DummyApp
  def initialize(&app)
    @app = app
    @called = false
  end

  def call(env)
    if @app
      @app&.call(env)
    else
      [200, {}, "body"]
    end
  ensure
    @called = true
  end

  def called?
    @called
  end
end
