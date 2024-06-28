class DummyApp
  def initialize(&app)
    @app = app
    @called = false
  end

  def call(env)
    @app&.call(env)
  ensure
    @called = true
  end

  def called?
    @called
  end
end
