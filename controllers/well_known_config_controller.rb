class WellKnownConfigController < MainController
  get "/.well-known/delegated-account-recovery/configuration" do
    JSON.pretty_generate(Darrrr.account_and_recovery_provider_config)
  end
end
