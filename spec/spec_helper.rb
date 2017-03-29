require "bundler/setup"
require "pry"
require "vcr"
require "webmock"
require "json"
require "watir"
require "capybara"
require "capybara/dsl"
require "capybara/poltergeist"
require "sinatra"
require "securerandom"
require 'database_cleaner'

ENV["ACCOUNT_PROVIDER_PUBLIC_KEY"] = "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEks3CjRTWrTnEDEiz36ICsy3mOX7fhauJ3Jj3R6hN7rp0Q6zh3WKIhGMBR8Ccc1VKZ4eMqLmw/WQLHSAn22GD4g=="
ENV["ACCOUNT_PROVIDER_PRIVATE_KEY"] = "MHcCAQEEIKrHDRd0Bn3PkY9fU4AaDErNIKPkMCdL9tGNvwyWXdPqoAoGCCqGSM49AwEHoUQDQgAEks3CjRTWrTnEDEiz36ICsy3mOX7fhauJ3Jj3R6hN7rp0Q6zh3WKIhGMBR8Ccc1VKZ4eMqLmw/WQLHSAn22GD4g=="
ENV["TOKEN_DATA_AES_KEY"] = "8d8aecbf68e51d72f1b95443e308db238c8984ec3fc4bf876e1a63643d211559"
ENV["RECOVERY_PROVIDER_PRIVATE_KEY"] = "MHcCAQEEIJ4GmCrFP2vxpNCyFo+XOicLVzplFpUkvvp0yWnuNK7hoAoGCCqGSM49AwEHoUQDQgAEcUoYO9viRDXApcOgjVWlA2e4GTwJV4DzysupSswayKGhZsZMeL2Tlsc4fKkTTyfdRWZ4C1ShO1XQWiowaa1q8w=="
ENV["RECOVERY_PROVIDER_PUBLIC_KEY"] = "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEcUoYO9viRDXApcOgjVWlA2e4GTwJV4DzysupSswayKGhZsZMeL2Tlsc4fKkTTyfdRWZ4C1ShO1XQWiowaa1q8w=="
ENV["COOKIE_SECRET"] = SecureRandom.hex
ENV["RACK_ENV"] = "test"

require 'simplecov'
require 'simplecov-json'
SimpleCov.formatters = [
  SimpleCov::Formatter::JSONFormatter,
  SimpleCov::Formatter::HTMLFormatter,
]
SimpleCov.start

Sinatra::Application.environment = :test
Capybara.javascript_driver = :poltergeist
Capybara.app = Rack::Builder.parse_file("config.ru").first

ActiveRecord::Base.logger = nil

Darrrr.register_account_provider("https://example-provider.org")
Darrrr.register_recovery_provider("https://example-provider.org")
Darrrr.register_recovery_provider("http://localhost:9292")

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = { record: :none, allow_playback_repeats: true }
  config.allow_http_connections_when_no_cassette = true
end

module DelegatedRecoveryHelpers
  def example_recovery_provider
    Darrrr.recovery_provider("https://example-provider.org").tap do |provider|
      provider.signing_private_key = "MHcCAQEEIIgnR3rlLFoqr9aND4Zy+2BybCBvHjBbXbZVl22iYJzloAoGCCqGSM49AwEHoUQDQgAEt8Q2mx9vXutOdCPlPP0J9qrJs/7aULPCXNyWfwOvt6k9vb2DIVqD3f7HlYOjZTt1xyUVAicfXbiuPA7sp/iaBA=="
    end
  end

  def example_account_provider
    Darrrr.account_provider("https://example-provider.org").tap do |provider|
      provider.signing_private_key = "MHcCAQEEIEhIgVNH4w+vt9pMe71GE3WBxz5yyCJUHl9/72RHFqdZoAoGCCqGSM49AwEHoUQDQgAE+LQRJeAXDpYknpWVn4lEKq0Q1ydH8c7GRcSmOzyLUvOXAxdl11spiqxuw13mHknoTRW0EutMo2gn9ID+uB0WpQ=="
    end
  end
end


RSpec.configure do |config|
  config.include DelegatedRecoveryHelpers
  config.include Capybara::DSL

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
