# frozen_string_literal: true

module GitHub
  module DelegatedAccountRecovery
    class EncryptedData
      extend Forwardable

      CIPHER = "aes-256-gcm".freeze
      CIPHER_VERSION = 0
      # This is the NIST recommended minimum: http://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf
      IV_LENGTH = 12
      AUTH_TAG_LENGTH = 16
      PROTOCOL_VERSION = 0

      attr_reader :token_object

      def_delegators :@token_object, :version, :iv, :auth_tag, :ciphertext,
        :to_binary_s, :num_bytes

      # token_object: either a EncryptedDataWriter or EncryptedDataReader
      # instance.
      def initialize(token_object)
        raise ArgumentError, "Version must be #{PROTOCOL_VERSION}. Supplied: #{token_object.version}" unless token_object.version == CIPHER_VERSION
        raise ArgumentError, "Auth Tag must be 16 bytes" unless token_object.auth_tag.length == AUTH_TAG_LENGTH
        raise ArgumentError, "IV must be 12 bytes" unless token_object.iv.length == IV_LENGTH
        @token_object = token_object
      end
      private_class_method :new

      def decrypt
        cipher = self.class.cipher(:decrypt, DelegatedAccountRecovery.this_account_provider.symmetric_key)
        cipher.iv = token_object.iv.to_binary_s
        cipher.auth_tag = token_object.auth_tag.to_binary_s
        cipher.auth_data = ""
        cipher.update(token_object.ciphertext.to_binary_s) + cipher.final
      rescue OpenSSL::Cipher::CipherError => e
        raise CryptoError, "Unable to decrypt data: #{e}"
      end

      class << self
        # data: the value to encrypt.
        #
        # returns an EncryptedData instance.
        def build(data)
          cipher = cipher(:encrypt, DelegatedAccountRecovery.this_account_provider.symmetric_key)
          iv = SecureRandom.random_bytes(IV_LENGTH)
          cipher.iv = iv
          cipher.auth_data = ""
          encrypted = cipher.update(data.to_s) + cipher.final

          token = EncryptedDataWriter.new.tap do |data|
            data.version = CIPHER_VERSION
            data.auth_tag = cipher.auth_tag.bytes
            data.iv = iv.bytes
            data.ciphertext = encrypted.bytes
          end

          new(token)
        end

        # serialized_data: the binary representation of a token.
        #
        # returns an EncryptedData instance.
        def parse(serialized_data)
          data = new(EncryptedDataReader.new.read(serialized_data))

          # be extra paranoid, oracles and stuff
          if data.num_bytes != serialized_data.bytesize
            raise CryptoError, "Encypted data field includes unexpected extra bytes"
          end

          data
        rescue IOError => e
          raise RecoveryTokenSerializationError, e.message
        end

        # DRY helper for generating cipher objects
        def cipher(mode, key)
          unless [:encrypt, :decrypt].include?(mode)
            raise ArgumentError, "mode must be `encrypt` or `decrypt`"
          end

          OpenSSL::Cipher.new(CIPHER).tap do |cipher|
            cipher.send(mode)
            cipher.key = [key].pack("H*")
          end
        end
      end
    end
  end
end
