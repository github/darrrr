# frozen_string_literal: true

# Handles binary serialization/deserialization of recovery token data. It does
# not manage signing/verification of tokens.
# Only account providers will ever call the decode function
module Darrrr
  class RecoveryToken
    extend Forwardable

    attr_reader :token_object

    def_delegators :@token_object, :token_id, :issuer, :issued_time, :options,
      :audience, :binding_data, :data, :version, :to_binary_s, :num_bytes,
      :data=, :token_type=, :token_type, :options=

    BASE64_CHARACTERS = /\A[0-9a-zA-Z+\/=]+\z/

    # Typically, you would not call `new` directly but instead use `build`
    # and `parse`
    #
    # token_object: a RecoveryTokenWriter/RecoveryTokenReader instance
    def initialize(token_object)
      @token_object = token_object
    end
    private_class_method :new

    def decode(context = nil)
      Darrrr.this_account_provider.encryptor.decrypt(self.data, Darrrr.this_account_provider, context)
    end

    # A globally known location of the token, used to initiate a recovery
    def state_url
      [Darrrr.recovery_provider(self.audience).recover_account, "id=#{CGI::escape(token_id.to_hex)}"].join("?")
    end

    class << self
      # data: the value that will be encrypted by EncryptedData.
      # audience: the provider for which we are building the token.
      # type: Either 0 (recovery token) or 1 (countersigned recovery token)
      # options: the value to set for the options byte
      #
      # returns a RecoveryToken.
      def build(issuer:, audience:, type:, options: 0x00)
        token = RecoveryTokenWriter.new.tap do |token|
          token.token_id = token_id
          token.issuer = issuer.origin
          token.issued_time = Time.now.utc.iso8601
          token.options = options
          token.audience = audience.origin
          token.version = Darrrr::PROTOCOL_VERSION
          token.token_type = type
        end
        new(token)
      end

      # token ID generates a random array of bytes.
      # this method only exists so that it can be stubbed.
      def token_id
        SecureRandom.random_bytes(16).bytes.to_a
      end

      # serialized_data: a binary string representation of a RecoveryToken.
      #
      # returns a RecoveryToken.
      def parse(serialized_data)
        new RecoveryTokenReader.new.read(serialized_data)
      rescue IOError => e
        message = e.message
        if serialized_data =~ BASE64_CHARACTERS
          message = "#{message}: did you forget to Base64.strict_decode64 this value?"
        end
        raise RecoveryTokenSerializationError, message
      end

      # Extract a recovery provider from a token based on the token type.
      #
      # serialized_data: a binary string representation of a RecoveryToken.
      #
      # returns the recovery provider for the coutnersigned token or raises an
      #   error if the token is a recovery token
      def recovery_provider_issuer(serialized_data)
        issuer(serialized_data, Darrrr::COUNTERSIGNED_RECOVERY_TOKEN_TYPE)
      end

      # Extract an account provider from a token based on the token type.
      #
      # serialized_data: a binary string representation of a RecoveryToken.
      #
      # returns the account provider for the recovery token or raises an error
      #   if the token is a countersigned token
      def account_provider_issuer(serialized_data)
        issuer(serialized_data, Darrrr::RECOVERY_TOKEN_TYPE)
      end

      # Convenience method to find the issuer of the token
      #
      # serialized_data: a binary string representation of a RecoveryToken.
      #
      # raises an error if the token is the not the expected type
      # returns the account provider or recovery provider instance based on the
      #   token type
      private def issuer(serialized_data, token_type)
        parsed_token = parse(serialized_data)
        raise TokenFormatError, "Token type must be #{token_type}" unless parsed_token.token_type == token_type

        issuer = parsed_token.issuer
        case token_type
        when Darrrr::RECOVERY_TOKEN_TYPE
          Darrrr.account_provider(issuer)
        when Darrrr::COUNTERSIGNED_RECOVERY_TOKEN_TYPE
          Darrrr.recovery_provider(issuer)
        else
          raise RecoveryTokenError, "Could not determine provider"
        end
      end
    end
  end
end
