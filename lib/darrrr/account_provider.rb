# frozen_string_literal: true

module Darrrr
  class AccountProvider
    include CryptoHelper
    include Provider
    private :seal

    # Only applicable when acting as a recovery provider
    PRIVATE_FIELDS = [:symmetric_key, :signing_private_key]

    FIELDS = [:tokensign_pubkeys_secp256r1].freeze
    URL_FIELDS = [:issuer, :save_token_return, :recover_account_return,
      :privacy_policy, :icon_152px].freeze

    # These are the fields required by the spec
    REQUIRED_FIELDS = FIELDS + URL_FIELDS

    attr_writer *REQUIRED_FIELDS
    attr_writer *PRIVATE_FIELDS
    attr_reader *(REQUIRED_FIELDS - [:tokensign_pubkeys_secp256r1])

    alias :origin :issuer

    # The CryptoHelper defines an `unseal` method that requires us to
    # define a `unseal_keys` method that will return the set of keys that
    # are valid when verifying the signature on a sealed key.
    #
    # returns the value of `tokensign_pubkeys_secp256r1` or executes a proc
    # passing `self` as the first argument.
    def unseal_keys(context = nil)
      if @tokensign_pubkeys_secp256r1.respond_to?(:call)
        @tokensign_pubkeys_secp256r1.call(self, context)
      else
        @tokensign_pubkeys_secp256r1
      end
    end

    # Used to serve content at /.well-known/delegated-account-recovery/configuration
    def to_h
      {
        "issuer" => self.issuer,
        "tokensign-pubkeys-secp256r1" => self.unseal_keys.dup,
        "save-token-return" => self.save_token_return,
        "recover-account-return" => self.recover_account_return,
        "privacy-policy" => self.privacy_policy,
        "icon-152px" => self.icon_152px
      }
    end

    # Generates a binary token with an encrypted arbitrary data payload.
    #
    # data: value to encrypt in the token
    # provider: the recovery provider/audience of the token
    # context: arbitrary data passed on to underlying crypto operations
    #
    # returns a [RecoveryToken, b64 encoded sealed_token] tuple
    def generate_recovery_token(data:, audience:, context: nil)
      token = RecoveryToken.build(issuer: self, audience: audience, type: RECOVERY_TOKEN_TYPE)
      token.data = Darrrr.encryptor.encrypt(data, self, context)

      [token, seal(token, context)]
    end

    # Parses a countersigned_token and returns the nested recovery token
    # WITHOUT verifying any signatures. This should only be used if no user
    # context can be identified or if we're extracting issuer information.
    def dangerous_unverified_recovery_token(countersigned_token)
      parsed_countersigned_token = RecoveryToken.parse(Base64.strict_decode64(countersigned_token))
      RecoveryToken.parse(parsed_countersigned_token.data)
    end

    # Validates the countersigned recovery token by verifying the signature
    # of the countersigned token, parsing out the origin recovery token,
    # verifying the signature on the recovery token, and finally decrypting
    # the data in the origin recovery token.
    #
    # countersigned_token: our original recovery token wrapped in recovery
    # token instance that is signed by the recovery provider.
    # context: arbitrary data to be passed to Provider#unseal.
    #
    # returns a verified recovery token or raises
    # an error if the token fails validation.
    def validate_countersigned_recovery_token!(countersigned_token, context = nil)
      # 5. Validate the the issuer field is present in the token,
      # and that it matches the audience field in the original countersigned token.
      begin
        recovery_provider = RecoveryToken.recovery_provider_issuer(Base64.strict_decode64(countersigned_token))
      rescue RecoveryTokenSerializationError => e
        raise CountersignedTokenError.new("Countersigned token is invalid: " + e.message, :countersigned_token_parse_error)
      rescue UnknownProviderError => e
        raise CountersignedTokenError.new(e.message, :recovery_token_invalid_issuer)
      end

      # 1. Parse the countersigned-token.
      # 2. Validate that the version field is 0.
      # 7. Retrieve the current Recovery Provider configuration as described in Section 2.
      # 8. Validate that the counter-signed token signature validates with a current element of the countersign-pubkeys-secp256r1 array.
      begin
        parsed_countersigned_token = recovery_provider.unseal(Base64.strict_decode64(countersigned_token), context)
      rescue TokenFormatError => e
        raise CountersignedTokenError.new(e.message, :countersigned_invalid_token_version)
      rescue CryptoError
        raise CountersignedTokenError.new("Countersigned token has an invalid signature", :countersigned_invalid_signature)
      end

      # 3. De-serialize the original recovery token from the data field.
      # 4. Validate the signature on the original recovery token.
      begin
        recovery_token = self.unseal(parsed_countersigned_token.data, context)
      rescue RecoveryTokenSerializationError => e
        raise CountersignedTokenError.new("Nested recovery token is invalid: " + e.message, :recovery_token_token_parse_error)
      rescue TokenFormatError => e
        raise CountersignedTokenError.new("Nested recovery token format error: #{e.message}", :recovery_token_invalid_token_type)
      rescue CryptoError
        raise CountersignedTokenError.new("Nested recovery token has an invalid signature", :recovery_token_invalid_signature)
      end

      # 5. Validate the the issuer field is present in the countersigned-token,
      # and that it matches the audience field in the original token.

      countersigned_token_issuer = parsed_countersigned_token.issuer
      if countersigned_token_issuer.blank? || countersigned_token_issuer != recovery_token.audience || recovery_provider.origin != countersigned_token_issuer
        raise CountersignedTokenError.new("Validate the the issuer field is present in the countersigned-token, and that it matches the audience field in the original token", :recovery_token_invalid_issuer)
      end

      # 6. Validate the token binding for the countersigned token, if present.
      # (the token binding for the inner token is not relevant)
      # TODO not required, to be implemented later

      # 9. Decrypt the data field from the original recovery token and parse its information, if present.
      # no decryption here is attempted. Attempts to call `decode` will just fail.

      # 10. Apply any additional processing which provider-specific data in the opaque data portion may indicate is necessary.
      begin
        if DateTime.parse(parsed_countersigned_token.issued_time).utc < (Time.now - CLOCK_SKEW).utc
          raise CountersignedTokenError.new("Countersigned recovery token issued at time is too far in the past", :stale_token)
        end
      rescue ArgumentError
        raise CountersignedTokenError.new("Invalid countersigned token issued time", :invalid_issued_time)
      end

      recovery_token
    end
  end
end
