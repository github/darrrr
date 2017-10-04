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

  it "passes context from high level operations to low level crypto calls when creating a token " do
    context = { foo: :bar }
    expect(Darrrr.this_account_provider.encryptor).to receive(:encrypt).with(anything, Darrrr.this_account_provider, context).and_return("crypted")
    expect(Darrrr.this_account_provider.encryptor).to receive(:sign).with(anything, anything, Darrrr.this_account_provider, context).and_return("signed")
    Darrrr.this_account_provider.generate_recovery_token(data: "plaintext", audience: Darrrr.this_recovery_provider, context: context)
  end

  it "passes context from high level operations to low level crypto calls when verifying/countersigning a token" do
    context = { foo: :bar }

    token, sealed_token = Darrrr.this_account_provider.generate_recovery_token(data: "foo", audience: Darrrr.this_recovery_provider)
    sealed_token = Base64.strict_decode64(sealed_token)

    expect(Darrrr.this_account_provider).to receive(:unseal_keys).with(context).and_return(["bar"])

    expect(Darrrr.this_account_provider.encryptor).to receive(:verify).with(anything, anything, anything, anything, context).and_return(true)
    Darrrr.this_recovery_provider.validate_recovery_token!(sealed_token, context)

    expect(Darrrr.this_recovery_provider.encryptor).to receive(:sign).with(anything, anything, anything, context).and_return("signed")
    Darrrr.this_recovery_provider.countersign_token(sealed_token, context)
  end

  it "passes context from high level operations to low level crypto calls when verifying/countersigning a token" do
    context = { foo: :bar }
    token, sealed_token = Darrrr.this_account_provider.generate_recovery_token(data: "foo", audience: Darrrr.this_recovery_provider)
    sealed_token = Base64.strict_decode64(sealed_token)
    countersigned_token = Darrrr.this_recovery_provider.countersign_token(sealed_token, context)

    expect(Darrrr.this_account_provider).to receive(:unseal_keys).with(context).and_return(["bar"])
    expect(Darrrr.this_account_provider.encryptor).to receive(:verify).with(anything, anything, anything, anything, context).and_return(true)
    expect(Darrrr.this_recovery_provider.encryptor).to receive(:verify).with(anything, anything, anything, anything, context).and_return(true)
    Darrrr.this_account_provider.validate_countersigned_recovery_token!(countersigned_token, context)
  end

  it "allows you to set the options value for a token" do
    token, _ = Darrrr.this_account_provider.generate_recovery_token(data: "foo", audience: Darrrr.this_recovery_provider, options: 0x02)
    expect(token.options).to eq(0x02)
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

        def sign(serialized_token, key, provider, context)
          "abc123"
        end

        def verify(payload, signature, key, provider, context)
          signature == "abc123"
        end

        def decrypt(encrypted_data, provider, context)
          rot13(encrypted_data)
        end

        def encrypt(data, provider, context)
          rot13(data)
        end
      end
    end

    let(:recovery_provider) { Darrrr.this_recovery_provider }
    let(:account_provider) { Darrrr.this_account_provider }

    it "rejects classes that don't define all operations" do
      expect {
        account_provider.custom_encryptor = BadEncryptor
      }.to raise_error(ArgumentError)
    end

    it "accepts classes that define all operations" do
      begin
        account_provider.custom_encryptor = Rot13Encryptor
        recovery_provider.custom_encryptor = Rot13Encryptor

        token, sealed_token = account_provider.generate_recovery_token(data: "foo", audience: recovery_provider)
        sealed_token = Base64.strict_decode64(sealed_token)
        recovery_provider.validate_recovery_token!(sealed_token)

        countersigned_token = recovery_provider.countersign_token(sealed_token)
        account_provider.validate_countersigned_recovery_token!(countersigned_token)

        unsealed_countersigned_token = recovery_provider.unseal(Base64.strict_decode64(countersigned_token))
        recovery_token = account_provider.unseal(unsealed_countersigned_token.data.to_binary_s)
        expect(recovery_token.decode).to eq("foo")
      ensure
        account_provider.instance_variable_set(:@encryptor, nil)
        recovery_provider.instance_variable_set(:@encryptor, nil)
      end
    end

    it "allows you to specify a temporary using a block" do
      expect(account_provider.encryptor).to be(Darrrr::DefaultEncryptor)

      account_provider.with_encryptor(Rot13Encryptor) do
        recovery_provider.with_encryptor(Rot13Encryptor) do
          expect(account_provider.encryptor).to be(Rot13Encryptor)
          expect(recovery_provider.encryptor).to be(Rot13Encryptor)
          token, sealed_token = account_provider.generate_recovery_token(data: "foo", audience: recovery_provider)
          sealed_token = Base64.strict_decode64(sealed_token)
          recovery_provider.validate_recovery_token!(sealed_token)

          countersigned_token = recovery_provider.countersign_token(sealed_token)
          account_provider.validate_countersigned_recovery_token!(countersigned_token)

          unsealed_countersigned_token = recovery_provider.unseal(Base64.strict_decode64(countersigned_token))
          recovery_token = account_provider.unseal(unsealed_countersigned_token.data.to_binary_s)
          expect(recovery_token.decode).to eq("foo")
        end
      end

      expect(account_provider.encryptor).to be(Darrrr::DefaultEncryptor)
      expect(recovery_provider.encryptor).to be(Darrrr::DefaultEncryptor)
    end
  end
end
