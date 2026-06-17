require "test_helper"

class YandexIamTokenProviderTest < ActiveSupport::TestCase
  test "returns ENV token in development and test fallback" do
    http_client = raising_http_client
    provider = YandexIamTokenProvider.new(
      http_client:,
      cache: ActiveSupport::Cache::MemoryStore.new,
      env: { "YANDEX_CLOUD_IAM_TOKEN" => "env-token" }
    )

    assert_equal "env-token", provider.call
  end

  test "gets token from metadata service in production" do
    http_client = fake_http_client(
      fake_response(200, { access_token: "metadata-token", expires_in: 3600 }.to_json)
    )
    provider = YandexIamTokenProvider.new(
      http_client:,
      cache: ActiveSupport::Cache::MemoryStore.new,
      env: {},
      rails_env: ActiveSupport::StringInquirer.new("production")
    )

    assert_equal "metadata-token", provider.call

    assert_equal 1, http_client.requests.size
    assert_equal "Google", http_client.requests.first["Metadata-Flavor"]
  end

  test "caches metadata token and does not repeat HTTP request" do
    http_client = fake_http_client(
      fake_response(200, { access_token: "cached-token", expires_in: 3600 }.to_json)
    )
    provider = YandexIamTokenProvider.new(
      http_client:,
      cache: ActiveSupport::Cache::MemoryStore.new,
      env: {},
      rails_env: ActiveSupport::StringInquirer.new("production")
    )

    assert_equal "cached-token", provider.call
    assert_equal "cached-token", provider.call

    assert_equal 1, http_client.requests.size
  end

  test "raises clear development error when ENV token is missing" do
    http_client = raising_http_client
    provider = YandexIamTokenProvider.new(
      http_client:,
      cache: ActiveSupport::Cache::MemoryStore.new,
      env: {}
    )

    error = assert_raises(RuntimeError) { provider.call }

    assert_equal(
      "YANDEX_CLOUD_IAM_TOKEN не задан. Добавьте токен в локальное окружение, чтобы распознавать чеки в development.",
      error.message
    )
  end

  test "raises clear production error when metadata fails and ENV token is missing" do
    provider = YandexIamTokenProvider.new(
      http_client: fake_http_client(fake_response(500, { message: "metadata unavailable" }.to_json)),
      cache: ActiveSupport::Cache::MemoryStore.new,
      env: {},
      rails_env: ActiveSupport::StringInquirer.new("production")
    )

    error = assert_raises(RuntimeError) { provider.call }

    assert_equal(
      "Не удалось получить Yandex Cloud IAM token: metadata service недоступен и YANDEX_CLOUD_IAM_TOKEN не задан",
      error.message
    )
  end

  private

  def fake_http_client(*responses)
    response_queue = responses.dup

    Class.new do
      attr_reader :requests

      define_method(:initialize) do |queue|
        @queue = queue
        @requests = []
      end

      def start(_hostname, _port, **_options)
        yield self
      end

      def request(request)
        @requests << request
        @queue.shift || raise("unexpected request")
      end
    end.new(response_queue)
  end

  def raising_http_client
    Class.new do
      def self.start(*)
        raise "metadata should not be requested"
      end
    end
  end

  def fake_response(code, body)
    Struct.new(:code, :body).new(code.to_s, body)
  end
end
