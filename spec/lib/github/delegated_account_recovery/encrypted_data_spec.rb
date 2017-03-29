# frozen_string_literal: true

require_relative "../../../spec_helper"

module Darrrr
  describe EncryptedData do
    let(:data) { EncryptedData.build("hai") }

    it "can generate and parse encrypted data" do
      parsed_token = EncryptedData.parse(data.to_binary_s)
      expect(data.decrypt).to eq(parsed_token.decrypt)
      expect("hai").to eq(parsed_token.decrypt)
    end

    it "raises errors on version mismatches version mismatch" do
      data.token_object.version = 100
      expect {
        EncryptedData.parse(data.to_binary_s)
      }.to raise_error(ArgumentError)
    end

    it "rejects tokens with an invalid auth_tag" do
      data.token_object.auth_tag = SecureRandom.random_bytes(EncryptedData::AUTH_TAG_LENGTH).bytes
      expect {
        EncryptedData.parse(data.to_binary_s).decrypt
      }.to raise_error(CryptoError)
    end

    it "raises an error when a token has bogus crypto primitives" do
      data.token_object.iv = SecureRandom.random_bytes(EncryptedData::IV_LENGTH).bytes
      expect {
        EncryptedData.parse(data.to_binary_s).decrypt
      }.to raise_error(CryptoError)
    end

    it "raises an error when data can't be decrypted" do
      data.token_object.ciphertext = ("garbage" + data.ciphertext.to_binary_s).bytes
      expect {
        EncryptedData.parse(data.to_binary_s).decrypt
      }.to raise_error(CryptoError)
    end

    it "truncated tokens raise crypto errors" do
      expect {
        EncryptedData.parse(data.to_binary_s[0..-3]).decrypt
      }.to raise_error(CryptoError)
    end

    it "invalid tokens raise parse errors" do
      expect {
        EncryptedData.parse("foooooo").decrypt
      }.to raise_error(RecoveryTokenSerializationError)
    end

    it "extra data at the end will raise an error" do
      expect {
        EncryptedData.parse(data.to_binary_s + "lululu").decrypt
      }.to raise_error(CryptoError)
    end
  end
end
