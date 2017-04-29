# frozen_string_literal: true

require_relative "../../../spec_helper"

module Darrrr
  describe RecoveryToken, vcr: { :cassette_name => "delegated_account_recovery/recovery_provider" } do
    let(:binding) { SecureRandom.hex }
    let(:recovery_provider) { example_account_provider }
    let(:token) { AccountProvider.this.generate_recovery_token(data: "hai", audience: recovery_provider) }

    it "can generate and parse a token" do
      parsed_token = RecoveryToken.parse(token.to_binary_s)
      expect(parsed_token.audience).to eq(recovery_provider.issuer)
    end

    it "token data can be decrypted" do
      parsed_token = RecoveryToken.parse(token.to_binary_s)
      data = parsed_token.decode

      expect(data).to_not be_nil
      expect("hai").to eq(data)
    end

    it "truncated tokens raise parse errors" do
      expect {
        RecoveryToken.parse(token.to_binary_s[0..-3])
      }.to raise_error(RecoveryTokenSerializationError)
    end

    it "invalid tokens raise parse errors" do
      expect {
        RecoveryToken.parse(token.to_binary_s.reverse)
      }.to raise_error(RecoveryTokenSerializationError)
    end

    it "extra data at the end of a token (e.g. a signature) does not cause errors" do
      RecoveryToken.parse(token.to_binary_s + "lululu") # assert_doesnt_raise_error
    end
  end
end
