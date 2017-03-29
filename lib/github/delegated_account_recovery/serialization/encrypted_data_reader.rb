# frozen_string_literal: true

module GitHub
  module DelegatedAccountRecovery
    class EncryptedDataReader < BinData::Record
      uint8 :version
      array :auth_tag, :type => :uint8, :read_until => lambda { index + 1 == EncryptedData::AUTH_TAG_LENGTH }
      array :iv, :type => :uint8, :read_until => lambda { index + 1 == EncryptedData::IV_LENGTH }
      array :ciphertext, :type => :uint8, :read_until => :eof
    end
  end
end
