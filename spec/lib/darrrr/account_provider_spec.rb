# frozen_string_literal: true

require_relative "../../spec_helper"

module Darrrr
  describe AccountProvider, vcr: { :cassette_name => "delegated_account_recovery/recovery_provider" } do
    let(:recovery_provider) { example_recovery_provider }
    let(:account_provider) { AccountProvider.this }
    let(:token) { account_provider.generate_recovery_token(data: "hai", audience: recovery_provider).first }

    # Generate a random key that isn't used during the sealing process.
    # openssl ecparam -name prime256v1 -genkey -noout -out prime256v1-key.pem
    # openssl ec -in prime256v1-key.pem -pubout -out prime256v1-pub.pem
    # cat prime256v1-pub.pem
    let(:unused_unseal_key) { "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAElAcL7Ki9+1QaGjZE6CLmfbEVqWjGYIm90rDp/Qy+kRCUyW6l5XSuffQyMWwq8rRMONmNzUk4rDgJr1hepp0y5w==" }

    def raw_token(recovery_token: nil, issuer: nil, version: nil, issued_time: nil, data: nil)
      RecoveryTokenWriter.new.tap do |token|
        token.token_id = SecureRandom.random_bytes(16).bytes.to_a
        token.issuer = issuer || recovery_provider.origin
        token.issued_time = issued_time || Time.now.utc.iso8601
        token.options = 0 # when the token-status endpoint is implemented, change this to 1
        token.audience = account_provider.origin
        token.token_type = COUNTERSIGNED_RECOVERY_TOKEN_TYPE
        token.version = version || PROTOCOL_VERSION
        token.data = data || Base64.strict_decode64(account_provider.send(:seal, recovery_token))
      end
    end

    it "provides extra options for faraday" do
      account_provider.faraday_config_callback = lambda do |faraday|
        faraday.headers["Accept-Encoding"] = :foo
        faraday.adapter(:typhoeus)
      end

      # assert extra header
      account_provider_faraday = account_provider.send(:faraday)
      expect(account_provider_faraday.headers).to include("Accept-Encoding" => :foo)

      # assert handler is property set
      handler = JSON.parse(account_provider_faraday.to_json)["builder"]["handlers"]
      expect(handler).to_not be_nil
      handler_name = handler.first["name"]
      expect(handler_name).to_not be_nil
      expect(handler_name).to eq("Faraday::Adapter::Typhoeus")
    end

    it "allows you to configure the recovery provider during retrieval" do
      account_provider = Darrrr.account_provider("https://example-provider.org") do |provider|
        binding.pry
        provider.faraday_config_callback = lambda do |faraday|
          faraday.adapter(Faraday.default_adapter)
          binding.pry
          faraday.headers["Accept-Encoding"] = "foo"
        end
      end

      expect(account_provider).to be_kind_of(Darrrr::AccountProvider)

      # assert extra header
      account_provider_faraday = account_provider.send(:faraday)
      expect(account_provider_faraday.headers).to include("Accept-Encoding" => "foo")
    end

    it "tokens can be sealed and unsealed" do
      payload = Base64.strict_decode64(account_provider.send(:seal, token))
      unsealed_token = account_provider.unseal(payload)
      expect(token.token_object).to eq(unsealed_token.token_object)
      expect("hai").to eq(unsealed_token.decode)
    end

    it "tokens can be sealed and unsealed when there are multiple unseal keys" do
      expect(account_provider).to receive(:unseal_keys).and_return(
        [account_provider.unseal_keys[0], unused_unseal_key]
      ).at_least(:once)
      payload = Base64.strict_decode64(account_provider.send(:seal, token))
      unsealed_token = account_provider.unseal(payload)
      expect(token.token_object).to eq(unsealed_token.token_object)
      expect("hai").to eq(unsealed_token.decode)
    end

    it "tokens can be sealed and unsealed when there are multiple unseal keys when ordered in reverse" do
      # Switch up the order just to make sure it works regardless of which comes first.
      expect(account_provider).to receive(:unseal_keys).and_return(
        [unused_unseal_key, account_provider.unseal_keys[0]]
      ).at_least(:once)

      payload = Base64.strict_decode64(account_provider.send(:seal, token))
      unsealed_token = account_provider.unseal(payload)
      expect(token.token_object).to eq(unsealed_token.token_object)
      expect("hai").to eq(unsealed_token.decode)
    end

    it "having no valid unseal keys raises errors" do
      expect(account_provider).to receive(:unseal_keys).and_return(
        [unused_unseal_key]
      )
      payload = Base64.strict_decode64(account_provider.send(:seal, token))
      expect { account_provider.unseal(payload) }.to raise_error(CryptoError)
    end

    it "invalid signatures raise errors" do
      # mess with the signature
      payload = Base64.strict_decode64(account_provider.send(:seal, token))
      payload[-1] = payload[-1].next

      expect { account_provider.unseal(payload) }.to raise_error(CryptoError)
    end

    it "invalid sealed tokens errors" do
      # mess with the token
      payload = Base64.strict_decode64(account_provider.send(:seal, token))
      payload = payload[1..-1]

      expect { account_provider.unseal(payload) }.to raise_error(RecoveryTokenSerializationError)
    end

    it "validates countersigned tokens" do
      sealed_token = Base64.strict_decode64(account_provider.send(:seal, token))
      countersigned_token = recovery_provider.countersign_token(token: sealed_token)
      expect(account_provider.validate_countersigned_recovery_token!(countersigned_token)).to_not be_nil
    end

    it "rejects countersigned tokens where the nested token has an invalid type" do
      token.token_object.version = 99999999
      countersigned_token = recovery_provider.send(:seal, raw_token(recovery_token: token))
      expect {
        account_provider.validate_countersigned_recovery_token!(countersigned_token)
      }.to raise_error(CountersignedTokenError, /Nested recovery token format error: Version field must be 0/)
    end

    it "rejects countersigned tokens with an invalid version number" do
      countersigned_token = recovery_provider.send(:seal, raw_token(recovery_token: token, version: 99999999))
      expect {
        account_provider.validate_countersigned_recovery_token!(countersigned_token)
      }.to raise_error(CountersignedTokenError, /Version field must be 0/)
    end

    it "rejects countersigned tokens with the unknown issuers" do
      token.token_object.audience = "https://fooooobarrrr.com"
      countersigned_token = recovery_provider.send(:seal, raw_token(recovery_token: token))
      expect {
        account_provider.validate_countersigned_recovery_token!(countersigned_token)
      }.to raise_error(CountersignedTokenError, /Validate the the issuer field is present in the countersigned-token, and that it matches the audience field in the original token/)
    end

    it "rejects countersigned tokens when the recovery token issuer is not the same as the countersigned token audience" do
      countersigned_token = recovery_provider.send(:seal, raw_token(recovery_token: token, issuer: "https://fooooooo.com"))
      expect {
        account_provider.validate_countersigned_recovery_token!(countersigned_token)
      }.to raise_error(CountersignedTokenError, /Unknown recovery provider/)
    end


    it "rejects stale countersigned tokens" do
      countersigned_token = recovery_provider.send(:seal, raw_token(recovery_token: token, issued_time: (Time.new - CLOCK_SKEW - 1).iso8601))
      expect {
        account_provider.validate_countersigned_recovery_token!(countersigned_token)
      }.to raise_error(CountersignedTokenError, /Countersigned recovery token issued at time is too far in the past/)

      countersigned_token = recovery_provider.send(:seal, raw_token(recovery_token: token, issued_time: ""))
      expect {
        account_provider.validate_countersigned_recovery_token!(countersigned_token)
      }.to raise_error(CountersignedTokenError, /Invalid countersigned token issued time/)

      countersigned_token = recovery_provider.send(:seal, raw_token(recovery_token: token, issued_time: "steve"))
      expect {
        account_provider.validate_countersigned_recovery_token!(countersigned_token)
      }.to raise_error(CountersignedTokenError, /Invalid countersigned token issued time/)
    end

    it "rejects countersigned tokens with an invalid signature" do
      countersigned_token = Base64.strict_decode64(recovery_provider.send(:seal, raw_token(recovery_token: token)))
      countersigned_token[-1] = countersigned_token[-1].next
      countersigned_token = Base64.strict_encode64(countersigned_token)

      expect {
        account_provider.validate_countersigned_recovery_token!(countersigned_token)
      }.to raise_error(CountersignedTokenError, /Countersigned token has an invalid signature/)
    end

    it "rejects invalid countersigned tokens" do
      countersigned_token = recovery_provider.send(:seal, raw_token(recovery_token: token))
      decoded = Base64.strict_decode64(countersigned_token)
      countersigned_token = Base64.strict_encode64(decoded[5..-1])

      expect {
        account_provider.validate_countersigned_recovery_token!(countersigned_token)
      }.to raise_error(CountersignedTokenError, /Countersigned token is invalid: data truncated/)
    end

    it "rejects contersigned tokens where the nested token's signature is invalid" do
      payload = Base64.strict_decode64(account_provider.send(:seal, token))
      payload[-1] = payload[-1].next
      countersigned_token = recovery_provider.send(:seal, raw_token(data: payload))

      expect {
        account_provider.validate_countersigned_recovery_token!(countersigned_token)
      }.to raise_error(CountersignedTokenError, /Nested recovery token has an invalid signature/)
    end

    it "rejects contersigned tokens where the nested token is invalid" do
      payload = Base64.strict_decode64(account_provider.send(:seal, token))
      payload = payload[1..-1].next
      countersigned_token = recovery_provider.send(:seal, raw_token(data: payload))

      expect {
        account_provider.validate_countersigned_recovery_token!(countersigned_token)
      }.to raise_error(CountersignedTokenError, /Nested recovery token is invalid: /)
    end

    it "rejects contersigned tokens where the nested token can't be decrypted" do
      garbage_data = EncryptedData.build("foo").to_binary_s
      garbage_data[-1] = garbage_data[-1].next
      token.data = garbage_data
      payload = Base64.strict_decode64(account_provider.send(:seal, token))
      countersigned_token = recovery_provider.seal(raw_token(data: payload))

      validated_token = account_provider.validate_countersigned_recovery_token!(countersigned_token)
      expect {
        validated_token.decode
      }.to raise_error(CryptoError, /Unable to decrypt data/)
    end
  end
end
