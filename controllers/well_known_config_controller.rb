# frozen_string_literal: true

class WellKnownConfigController < MainController
  get "/.well-known/delegated-account-recovery/configuration" do
    JSON.pretty_generate(Darrrr.account_and_recovery_provider_config)
  end

  get "/" do
    redirect "/account-provider"
  end
end
