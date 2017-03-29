# frozen_string_literal: true

module GitHub
  module DelegatedAccountRecovery
    class EncryptedDataWriter < BinData::Record
      uint8 :version
      array :auth_tag, :type => :uint8, :initial_length => EncryptedData::AUTH_TAG_LENGTH
      array :iv, :type => :uint8, :initial_length => EncryptedData::IV_LENGTH
      array :ciphertext, :type => :uint8
    end
  end
end
