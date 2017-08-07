# frozen_string_literal: true

require_relative "../../spec_helper"

module Darrrr
  describe RecoveryProvider, vcr: { :cassette_name => "delegated_account_recovery/recovery_provider" } do
    include DelegatedRecoveryHelpers

    let(:recovery_provider) { example_recovery_provider }
    let(:account_provider) { AccountProvider.this }
    let(:token) { account_provider.generate_recovery_token(data: "data", audience: recovery_provider) }

    let(:raw_token) do
      RecoveryTokenWriter.new.tap do |token|
        token.token_id = SecureRandom.random_bytes(16).bytes.to_a
        token.issuer = account_provider.issuer
        token.issued_time = Time.now.utc.iso8601
        token.options = 0 # when the token-status endpoint is implemented, change this to 1
        token.audience = recovery_provider.issuer
        token.binding_data = "foo"
        token.token_type = RECOVERY_TOKEN_TYPE
        token.version = PROTOCOL_VERSION
        token.data = EncryptedData.build("data").to_binary_s
      end
    end

    # Generate a random key that isn't used during the sealing process.
    # openssl ecparam -name prime256v1 -genkey -noout -out prime256v1-key.pem
    # openssl ec -in prime256v1-key.pem -pubout -out prime256v1-pub.pem
    # cat prime256v1-pub.pem
    let(:unused_unseal_key) { "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAElAcL7Ki9+1QaGjZE6CLmfbEVqWjGYIm90rDp/Qy+kRCUyW6l5XSuffQyMWwq8rRMONmNzUk4rDgJr1hepp0y5w==" }

    let(:config) do
      {
         "issuer" => "https://example-provider.org",
         "countersign-pubkeys-secp256r1" =>  [
            "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEo6KcKtGsBuRHbwtg6xOQlmd5ECwgcBsxeNGpZzEnIS+SUFQnSARacWOgU7rfezqu4lVxuXa55rYvtyYZ8TCRqg=="
         ],
         "token-max-size" => 8192,
         "save-token" => "https://example-provider.org/recovery/delegated/save",
         "recover-account" => "https://example-provider.org/recovery/delegated/recover",
         "save-token-async-api-iframe" => "https://example-provider.org/plugins/delegated_account_recovery",
         "privacy-policy" => "https://example-provider.org/about/privacy/"
      }
    end

    it "does not accept in incomplete config" do
      config.delete("issuer")
      expect {
        RecoveryProvider.new("https://example-provider.org", attrs: config)
      }.to raise_error(ProviderConfigError)
    end

    it "does not accept a config missing a public key" do
      config.delete("countersign-pubkeys-secp256r1")
      expect {
        RecoveryProvider.new("https://example-provider.org", attrs: config)
      }.to raise_error(ProviderConfigError)
    end

    it "reports 404 errors when retrieving configs" do
      expect {
        RecoveryProvider.new("https://www.faceboooooook.com").load
      }.to raise_error(ProviderConfigError)
    end

    it "reports JSON parse errors when retrieving configs" do
      expect {
        RecoveryProvider.new("https://bad-json.com").load
      }.to raise_error(ProviderConfigError)
    end

    it "does not accept configs with invalid URLs" do
      config["save-token"] = "totally not a URL!!111 :)"
      expect {
        RecoveryProvider.new("https://example-provider.org", attrs: config)
      }.to raise_error(ProviderConfigError)
    end

    it "can verify recovery tokens" do
      sealed_token = account_provider.seal(token)
      expect(recovery_provider.validate_recovery_token!(Base64.strict_decode64(sealed_token))).to_not be_nil
    end

    it "rejects tokens with invalid signatures" do
      sealed_token = account_provider.seal(token)[0..-5]
      expect {
        recovery_provider.validate_recovery_token!(Base64.strict_decode64(sealed_token))
      }.to raise_error(RecoveryTokenError, /Unable to verify signature of token/)
    end

    it "rejects invalid tokens" do
      sealed_token = account_provider.seal(token)[5..0]
      expect {
        recovery_provider.validate_recovery_token!(Base64.strict_decode64(sealed_token))
      }.to raise_error(RecoveryTokenError, /Could not determine provider/)
    end

    it "rejects tokens with invalid version numbers" do
      raw_token.version = 9999999

      sealed_token = account_provider.seal(RecoveryToken.parse(raw_token.to_binary_s))
      expect {
        recovery_provider.validate_recovery_token!(Base64.strict_decode64(sealed_token))
      }.to raise_error(RecoveryTokenError, /Version field must be 0/)
    end

    it "rejects tokens with an 'old' issued at date" do
      raw_token.issued_time = (Time.new - CLOCK_SKEW - 1).iso8601
      sealed_token = account_provider.seal(RecoveryToken.parse(raw_token.to_binary_s))
      expect {
        recovery_provider.validate_recovery_token!(Base64.strict_decode64(sealed_token))
      }.to raise_error(RecoveryTokenError, /Issued at time is too far in the past/)
    end

    it "rejects tokens with an invalid issuer" do
      raw_token.audience = "foo.bar"
      sealed_token = account_provider.seal(RecoveryToken.parse(raw_token.to_binary_s))
      expect {
        recovery_provider.validate_recovery_token!(Base64.strict_decode64(sealed_token))
      }.to raise_error(RecoveryTokenError, /Unnacceptable audience/)
    end

    it "rejects tokens with an invalid token type" do
      raw_token.token_type = 999999999
      sealed_token = account_provider.seal(RecoveryToken.parse(raw_token.to_binary_s))
      expect {
        recovery_provider.validate_recovery_token!(Base64.strict_decode64(sealed_token))
      }.to raise_error(RecoveryTokenError, /Token type must be 0/)
    end

    it "countersigns tokens" do
      sealed_token = Base64.strict_decode64(account_provider.seal(token))
      countersigned_token = recovery_provider.countersign_token(sealed_token)
      raw_counter_token = recovery_provider.unseal(Base64.strict_decode64(countersigned_token))
      expect(sealed_token).to eq(raw_counter_token.data.to_binary_s)
      expect(account_provider.unseal(raw_counter_token.data.to_binary_s)).to_not be_nil
    end

    it "countersigned tokens can be unsealed when there are multiple unseal keys" do
      expect(recovery_provider).to receive(:unseal_keys).and_return(
        [recovery_provider.unseal_keys[0], unused_unseal_key]
      )
      sealed_token = Base64.strict_decode64(account_provider.seal(token))
      countersigned_token = recovery_provider.countersign_token(sealed_token)
      raw_counter_token = recovery_provider.unseal(Base64.strict_decode64(countersigned_token))
      expect(sealed_token).to eq(raw_counter_token.data.to_binary_s)
      expect(account_provider.unseal(sealed_token)).to_not be_nil
    end

    it "countersigned tokens can be unsealed when there are multiple unseal keys when the order is swapped" do
      # Switch up the order just to make sure it works regardless of which comes first.
      expect(recovery_provider).to receive(:unseal_keys).and_return(
        [unused_unseal_key, recovery_provider.unseal_keys[0]]
      )
      sealed_token = Base64.strict_decode64(account_provider.seal(token))
      countersigned_token = recovery_provider.countersign_token(sealed_token)
      raw_counter_token = recovery_provider.unseal(Base64.strict_decode64(countersigned_token))
      expect(sealed_token).to eq(raw_counter_token.data.to_binary_s)
      expect(account_provider.unseal(sealed_token)).to_not be_nil
    end

    it "doesn't countersign tokens it can't parse" do
      sealed_token = Base64.strict_decode64(account_provider.seal(token)).reverse
      expect {
        recovery_provider.countersign_token(sealed_token)
      }.to raise_error(TokenFormatError)
    end

    it "having no valid countersign unseal keys raises errors" do
      expect(recovery_provider).to receive(:unseal_keys).and_return(
        [unused_unseal_key]
      )
      sealed_token = Base64.strict_decode64(account_provider.seal(token))
      countersigned_token = recovery_provider.countersign_token(sealed_token)
      expect {
        recovery_provider.unseal(Base64.strict_decode64(countersigned_token))
      }.to raise_error(CryptoError)
    end
  end
end
