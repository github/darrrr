$stdout.sync = true
require_relative "app"
require_relative "controllers/account_provider_controller"
require_relative "controllers/recovery_provider_controller"
require_relative "controllers/well_known_config_controller"

configure do
  use Rack::Session::Cookie, :secret => ENV["COOKIE_SECRET"]
  unless Sinatra::Application.environment == :test
    use Rack::Csrf, :raise => true, :skip => MainController::UNAUTHED_ENDPOINTS
  end
end

map(MainController::ACCOUNT_PROVIDER_PATH) { run AccountProviderController }
map(MainController::RECOVERY_PROVIDER_PATH) { run RecoveryProviderController }
map("/") { run WellKnownConfigController }
set :database_file, File.expand_path("../config/database.yml", __FILE__)

run Sinatra::Application
