Mixlib::Authorization::Config.authorization_service_uri = "http://localhost:9463"

class TestingStatsClient
  attr_reader :times_called

  def initialize
    @times_called = 0
  end

  def db_call
    @times_called += 1
    yield
  end
end

Opscode::Mappers.use_dev_config
include Opscode::Models
