# frozen_string_literal: true

module Darrrr
  class RecoveryTokenWriter < BinData::Record
    uint8 :version
    uint8 :token_type
    array :token_id, type: :uint8, initial_length: Darrrr::TOKEN_ID_BYTE_LENGTH
    uint8 :options
    uint16be :issuer_length, value: lambda { issuer.length }
    string :issuer
    uint16be :audience_length, value: lambda { audience.length }
    string :audience
    uint16be :issued_time_length, value: lambda { issued_time.length }
    string :issued_time
    uint16be :data_length, value: lambda { data.length }
    string :data
    uint16be :binding_data_length, value: lambda { binding_data.length }
    string :binding_data
  end
end
