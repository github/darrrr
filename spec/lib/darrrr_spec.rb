# frozen_string_literal: true

require_relative "../spec_helper"

describe Darrrr, vcr: { :cassette_name => "delegated_account_recovery/recovery_provider" } do
  context "#recovery_provider" do
    it "raises an error if you ask for an unregistered recovery provider" do
      expect {
        Darrrr.recovery_provider("https://not-registered.com")
      }.to raise_error(Darrrr::UnknownProviderError)
    end

    it "returns a registered recovery provider" do
      expect(Darrrr.recovery_provider("https://example-provider.org")).to be_kind_of(Darrrr::RecoveryProvider)
    end
  end

  context "#register_recovery_provider" do
    it "allows registering domains" do
      begin
        before = Darrrr.recovery_providers

        new_provider = "https://www.new-provider.com"
        expect {
          Darrrr.recovery_provider(new_provider)
        }.to raise_error(Darrrr::UnknownProviderError)

        Darrrr.register_recovery_provider(new_provider)
        expect(Darrrr.recovery_provider(new_provider)).to be_kind_of(Darrrr::RecoveryProvider)
      ensure
        Darrrr.instance_variable_set(:@recovery_providers, before)
      end
    end
  end

  context "#account_provider" do
    it "raises an error if you ask for an unregistered account provider" do
      expect {
        Darrrr.account_provider("https://not-registered.com")
      }.to raise_error(Darrrr::UnknownProviderError)
    end

    it "returns a registered account provider" do
      expect(Darrrr.account_provider("https://example-provider.org")).to be_kind_of(Darrrr::AccountProvider)
    end
  end

  it "allows procs as values for tokensign_pubkeys_secp256r1" do
    expect(Darrrr.this_account_provider.instance_variable_get(:@tokensign_pubkeys_secp256r1)).to be_a(Proc)
    expect(Darrrr.this_account_provider.unseal_keys).to eq([ENV["ACCOUNT_PROVIDER_PUBLIC_KEY"]])
  end

  it "allows procs as values for countersign_pubkeys_secp256r1" do
    expect(Darrrr.this_recovery_provider.instance_variable_get(:@countersign_pubkeys_secp256r1)).to be_a(Proc)
    expect(Darrrr.this_recovery_provider.unseal_keys).to eq([ENV["RECOVERY_PROVIDER_PUBLIC_KEY"]])
  end

  context "#account_provider_config" do
    it "returns a hash" do
      expect(Darrrr.account_provider_config).to be_kind_of(Hash)
    end
  end

  context "#recovery_provider_config" do
    it "returns a hash" do
      expect(Darrrr.recovery_provider_config).to be_kind_of(Hash)
    end
  end

  context "#account_and_recovery_provider_config" do
    it "returns a hash" do
      expect(Darrrr.account_and_recovery_provider_config).to be_kind_of(Hash)
    end
  end

  context "#custom_encryptor=" do
    module BadEncryptor

    end

    module Rot13Encryptor
      class << self
        # credit: https://gist.github.com/rwoeber/274126
        def rot13(string)
          string.tr("A-Za-z", "N-ZA-Mn-za-m")
        end

        def sign(serialized_token, key)
          "abc123"
        end

        def verify(payload, signature, key)
          signature == "abc123"
        end

        def decrypt(encrypted_data)
          rot13(encrypted_data)
        end

        def encrypt(data)
          rot13(data)
        end
      end
    end

    let(:recovery_provider) { Darrrr.this_recovery_provider }
    let(:account_provider) { Darrrr.this_account_provider }

    it "rejects classes that don't define all operations" do
      expect {
        Darrrr.custom_encryptor = BadEncryptor
      }.to raise_error(ArgumentError)
    end

    it "accepts classes that define all operations" do
      begin
        Darrrr.custom_encryptor = Rot13Encryptor

        token = account_provider.generate_recovery_token(data: "foo", audience: recovery_provider)
        sealed_token = Base64.strict_decode64(account_provider.seal(token))
        recovery_provider.validate_recovery_token!(sealed_token)

        countersigned_token = recovery_provider.countersign_token(sealed_token)
        account_provider.validate_countersigned_recovery_token!(countersigned_token)

        unsealed_countersigned_token = recovery_provider.unseal(Base64.strict_decode64(countersigned_token))
        recovery_token = account_provider.unseal(unsealed_countersigned_token.data.to_binary_s)
        expect(recovery_token.decode).to eq("foo")
      ensure
        Darrrr.instance_variable_set(:@encryptor, nil)
      end
    end

    it "allows you to specify a temporary using a block" do
      expect(Darrrr.encryptor).to be(Darrrr::DefaultEncryptor)

      Darrrr.with_encryptor(Rot13Encryptor) do
        expect(Darrrr.encryptor).to be(Rot13Encryptor)
        token = account_provider.generate_recovery_token(data: "foo", audience: recovery_provider)
        sealed_token = Base64.strict_decode64(account_provider.seal(token))
        recovery_provider.validate_recovery_token!(sealed_token)


        countersigned_token = recovery_provider.countersign_token(sealed_token)
        account_provider.validate_countersigned_recovery_token!(countersigned_token)

        unsealed_countersigned_token = recovery_provider.unseal(Base64.strict_decode64(countersigned_token))
        recovery_token = account_provider.unseal(unsealed_countersigned_token.data.to_binary_s)
        expect(recovery_token.decode).to eq("foo")
      end

      expect(Darrrr.encryptor).to be(Darrrr::DefaultEncryptor)
    end
  end
end
