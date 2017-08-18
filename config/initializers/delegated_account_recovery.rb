# frozen_string_literal: true

Darrrr.cache = nil # for caching remote configs
Darrrr.authority = ENV["HOST_URL"] || "http://localhost:9292"
Darrrr.privacy_policy = "#{Darrrr.authority}/articles/github-privacy-statement/"
Darrrr.icon_152px = "#{Darrrr.authority}/icon.png"

Darrrr::AccountProvider.configure do |config|
  config.signing_private_key = ENV["ACCOUNT_PROVIDER_PRIVATE_KEY"]
  config.symmetric_key = ENV["TOKEN_DATA_AES_KEY"]
  config.tokensign_pubkeys_secp256r1 = lambda do |context|
    [ENV["ACCOUNT_PROVIDER_PUBLIC_KEY"]]
  end
  config.save_token_return = "#{Darrrr.authority}/account-provider/save-token-return"
  config.recover_account_return = "#{Darrrr.authority}/account-provider/recover-account-return"
end

Darrrr::RecoveryProvider.configure do |config|
  config.signing_private_key = ENV["RECOVERY_PROVIDER_PRIVATE_KEY"]
  config.countersign_pubkeys_secp256r1 = lambda do |context|
    [ENV["RECOVERY_PROVIDER_PUBLIC_KEY"]]
  end
  config.token_max_size = 8192
  config.save_token = "#{Darrrr.authority}/recovery-provider/save-token"
  config.recover_account = "#{Darrrr.authority}/recovery-provider/recover-account"
end

Darrrr.register_account_provider(Darrrr.authority)
Darrrr.register_recovery_provider(Darrrr.authority)

options = { :namespace => "app_v1", :compress => true }

# Uncomment to use memcached
# Darrrr.cache = Dalli::Client.new('localhost:11211', options)

Darrrr.allow_unsafe_urls = true
