# frozen_string_literal: true

module GitHub
  module DelegatedAccountRecovery
    module CryptoHelper
      include Constants
      # Signs the provided token and joins the data with the signature.
      #
      # token: a RecoveryToken instance
      #
      # returns a base64 value for the binary token string and the signature
      # of the token.
      def seal(token)
        raise RuntimeError, "signing private key must be set" unless self.signing_private_key
        binary_token = token.to_binary_s
        signature = sign(binary_token, self.signing_private_key)
        Base64.strict_encode64([binary_token, signature].join)
      end

      # Splits the payload by the token size, treats the remaining portion as
      # the signature of the payload, and verifies the signature is valid for
      # the given payload.
      #
      # token_and_signature: binary string consisting of [token_binary_str, signature].join
      # keys - An array of public keys to use for signature verification.
      #
      # returns a RecoveryToken if the payload has been verified and
      # deserializes correctly. Raises exceptions if any crypto fails.
      # Raises an error if the token's version field is not valid.
      def unseal(token_and_signature)
        token = RecoveryToken.parse(token_and_signature)

        unless token.version.to_i == PROTOCOL_VERSION
          raise TokenFormatError, "Version field must be #{PROTOCOL_VERSION}"
        end

        token_data, signature = partition_signed_token(token_and_signature, token)
        self.unseal_keys.each do |key|
          return token if verify(token_data, signature, key)
        end
        raise CryptoError, "Recovery token signature was invalid"
      end

      # serialized_token: binary serialized recovery token (to_binary_s).
      # key: the private EC key used to sign the token
      def sign(serialized_token, key)
        digest = DIGEST.new.digest(serialized_token)
        ec = OpenSSL::PKey::EC.new(Base64.strict_decode64(key))
        ec.dsa_sign_asn1(digest)
      end

      # payload: token in binary form
      # signature: signature of the binary token
      # key: the EC public key used to verify the signature
      #
      # returns whether or not the signature validates the payload
      def verify(payload, signature, key)
        public_key_hex = format_key(key)
        key = OpenSSL::PKey::EC.new(GROUP)
        public_key_bn = OpenSSL::BN.new(public_key_hex, 16)
        public_key = OpenSSL::PKey::EC::Point.new(GROUP, public_key_bn)
        key.public_key = public_key

        key.dsa_verify_asn1(DIGEST.new.digest(payload), signature)
      rescue OpenSSL::PKey::ECError => e
        raise CryptoError, "Unable verify recovery token"
      end

      private

      def base64_to_hex(b64)
        Base64.strict_decode64(b64).unpack("H*").first
      end

      def format_key(key)
        hex_key = base64_to_hex(key)
        if hex_key.start_with?(ASN1_PREFIX)
          hex_key[ASN1_PREFIX.length..-1]
        else
          raise CryptoError, "Invalid public key format. The key must be in ASN.1 format."
        end
      end

      # Split the binary token into the token data and the signature over the
      # data.
      #
      # token_and_signature: binary serialization of the token and signature for the token
      # recovery_token: a RecoveryToken object parsed from token_and_signature
      #
      # returns a two element array of [token, signature]
      def partition_signed_token(token_and_signature, recovery_token)
        token_length = recovery_token.num_bytes
        [token_and_signature[0...token_length], token_and_signature[token_length..-1]]
      end
    end
  end
end
