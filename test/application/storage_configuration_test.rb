require "test_helper"

class StorageConfigurationTest < ActiveSupport::TestCase
  test "yandex active storage service is configured as private s3-compatible storage" do
    config = storage_configuration.fetch("yandex")

    assert_equal "S3", config.fetch("service")
    assert_equal "ru-central1", config.fetch("region")
    assert_equal "https://storage.yandexcloud.net", config.fetch("endpoint")
    assert_equal true, config.fetch("force_path_style")
    assert_equal false, config.fetch("public")
  end

  test "production uses yandex active storage service" do
    production_config = Rails.root.join("config/environments/production.rb").read

    assert_includes production_config, "config.active_storage.service = :yandex"
  end

  private

  def storage_configuration
    YAML.safe_load(
      ERB.new(Rails.root.join("config/storage.yml").read).result,
      aliases: true
    )
  end
end
