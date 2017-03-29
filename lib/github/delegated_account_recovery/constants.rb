# frozen_string_literal: true

module GitHub
  module DelegatedAccountRecovery
    module Constants
      PROTOCOL_VERSION = 0
      PRIME_256_V1 = "prime256v1" # AKA secp256r1
      GROUP = OpenSSL::PKey::EC::Group.new(PRIME_256_V1)
      DIGEST = OpenSSL::Digest::SHA256
      TOKEN_ID_BYTE_LENGTH = 16
      RECOVERY_TOKEN_TYPE = 0
      COUNTERSIGNED_RECOVERY_TOKEN_TYPE = 1
      WELL_KNOWN_CONFIG_PATH = ".well-known/delegated-account-recovery/configuration"

      # Ruby doesn't like ASN.1 representations of public keys. Get the "raw"
      # ECPoint representation by removing the static prefix:
      ASN1_PREFIX = [
        48, 89, 48, 19, 6, 7, 42, 134, 72, 206, 61, 2,
        1, 6, 8, 42, 134, 72, 206, 61, 3, 1, 7, 3, 66, 0
      ].map {|i| i.to_s(16).rjust(2, "0")}.join.freeze

      CLOCK_SKEW = 5.minutes
    end

    include Constants
  end
end
