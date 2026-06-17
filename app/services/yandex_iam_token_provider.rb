require "json"
require "net/http"
require "uri"

# In Yandex Serverless Containers, attach a service account to the container
# revision. The account needs permissions for Yandex Vision OCR and YandexGPT.
class YandexIamTokenProvider
  METADATA_TOKEN_URL = "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token"
  CACHE_KEY = "yandex_cloud_iam_token"
  METADATA_TIMEOUT_SECONDS = 2

  def initialize(http_client: Net::HTTP, cache: Rails.cache, env: ENV, rails_env: Rails.env)
    @http_client = http_client
    @cache = cache
    @env = env
    @rails_env = rails_env
  end

  def call
    cached_token = cache.read(CACHE_KEY)
    return cached_token if cached_token.present?

    if rails_env.production?
      metadata_token || env_token || raise_missing_token!
    else
      env_token || raise_missing_development_token!
    end
  end

  private

  attr_reader :http_client, :cache, :env, :rails_env

  def env_token
    env["YANDEX_CLOUD_IAM_TOKEN"].to_s.strip.presence
  end

  def metadata_token
    response = request_metadata_token
    return nil unless response.code.to_i.between?(200, 299)

    payload = JSON.parse(response.body)
    token = payload["access_token"].to_s.strip
    expires_in = payload["expires_in"].to_i

    return nil if token.blank? || expires_in <= 0

    cache.write(CACHE_KEY, token, expires_in: cache_ttl(expires_in))
    token
  rescue JSON::ParserError, StandardError
    nil
  end

  def request_metadata_token
    uri = URI(METADATA_TOKEN_URL)
    request = Net::HTTP::Get.new(uri)
    request["Metadata-Flavor"] = "Google"

    http_client.start(
      uri.hostname,
      uri.port,
      open_timeout: METADATA_TIMEOUT_SECONDS,
      read_timeout: METADATA_TIMEOUT_SECONDS,
      use_ssl: uri.scheme == "https"
    ) do |http|
      http.request(request)
    end
  end

  def cache_ttl(expires_in)
    ttl = expires_in > 300 ? expires_in - 300 : expires_in / 2

    [ ttl, 1 ].max.seconds
  end

  def raise_missing_token!
    raise "Не удалось получить Yandex Cloud IAM token: metadata service недоступен и YANDEX_CLOUD_IAM_TOKEN не задан"
  end

  def raise_missing_development_token!
    raise "YANDEX_CLOUD_IAM_TOKEN не задан. Добавьте токен в локальное окружение, чтобы распознавать чеки в development."
  end
end
