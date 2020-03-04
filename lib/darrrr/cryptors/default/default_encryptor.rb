# frozen_string_literal: true

module Darrrr
  module DefaultEncryptor
    class << self
      include Constants

      # Encrypts the data in an opaque way
      #
      # data: the secret to be encrypted
      # context: arbitrary data originally passed in via Provider#seal
      #
      # returns a byte array representation of the data
      def encrypt(data, _provider, _context = nil)
        EncryptedData.build(data).to_binary_s.b
      end

      # Decrypts the data
      #
      # ciphertext: the byte array to be decrypted
      # context: arbitrary data originally passed in via RecoveryToken#decode
      #
      # returns a string
      def decrypt(ciphertext, _provider, _context = nil)
        EncryptedData.parse(ciphertext).decrypt
      end


      # payload: binary serialized recovery token (to_binary_s).
      #
      # key: the private EC key used to sign the token
      # context: arbitrary data originally passed in via Provider#seal
      #
      # returns signature in ASN.1 DER r + s sequence
      def sign(payload, key, _provider, context = nil)
        digest = DIGEST.new.digest(payload)
        ec = OpenSSL::PKey::EC.new(Base64.strict_decode64(key))
        ec.dsa_sign_asn1(digest)
      end

      # payload: token in binary form
      # signature: signature of the binary token
      # key: the EC public key used to verify the signature
      # context: arbitrary data originally passed in via #unseal
      #
      # returns true if signature validates the payload
      def verify(payload, signature, key, _provider, _context = nil)
        public_key_hex = format_key(key)
        pkey = OpenSSL::PKey::EC.new(GROUP)
        public_key_bn = OpenSSL::BN.new(public_key_hex, 16)
        public_key = OpenSSL::PKey::EC::Point.new(GROUP, public_key_bn)
        pkey.public_key = public_key

        pkey.verify(DIGEST.new, signature, payload)
      rescue OpenSSL::PKey::ECError, OpenSSL::PKey::PKeyError => e
        raise CryptoError, "Unable verify recovery token"
      end

      private def format_key(key)
        sequence, bit_string = OpenSSL::ASN1.decode(Base64.decode64(key)).value
        unless bit_string.try(:tag) == OpenSSL::ASN1::BIT_STRING
          raise CryptoError, "DER-encoded key did not contain a bit string"
        end
        bit_string.value.unpack("H*").first
      rescue OpenSSL::ASN1::ASN1Error => e
        raise CryptoError, "Invalid public key format. The key must be in ASN.1 format. #{e.message}"
      end
    end
  end
end
