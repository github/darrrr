# frozen_string_literal: true

module Darrrr
  module Constants
    PROTOCOL_VERSION = 0
    PRIME_256_V1 = "prime256v1" # AKA secp256r1
    GROUP = OpenSSL::PKey::EC::Group.new(PRIME_256_V1)
    DIGEST = OpenSSL::Digest::SHA256
    TOKEN_ID_BYTE_LENGTH = 16
    RECOVERY_TOKEN_TYPE = 0
    COUNTERSIGNED_RECOVERY_TOKEN_TYPE = 1
    WELL_KNOWN_CONFIG_PATH = ".well-known/delegated-account-recovery/configuration"
    CLOCK_SKEW = 5 * 60
  end

  include Constants
end
