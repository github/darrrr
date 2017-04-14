# frozen_string_literal: true

module GitHub
  module DelegatedAccountRecovery
    class RecoveryTokenReader < BinData::Record
      uint8 :version
      uint8 :token_type
      array :token_id, :type => :uint8, :read_until => lambda { index + 1 == DelegatedAccountRecovery::TOKEN_ID_BYTE_LENGTH }
      uint8 :options
      uint16be :issuer_length
      string :issuer, :read_length => :issuer_length
      uint16be :audience_length
      string :audience, :read_length => :audience_length
      uint16be :issued_time_length
      string :issued_time, :read_length => :issued_time_length
      uint16be :data_length
      string :data, :read_length => :data_length
      uint16be :binding_data_length
      string :binding_data, :read_length => :binding_data_length
    end
  end
end
