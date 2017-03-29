# frozen_string_literal: true

module GitHub
  module DelegatedAccountRecovery
    class RecoveryProvider
      include CryptoHelper
      include Provider

      INTEGER_FIELDS = [:token_max_size]
      BASE64_FIELDS = [:countersign_pubkeys_secp256r1]
      URL_FIELDS = [
        :issuer, :save_token,
        :recover_account, :privacy_policy
      ]
      REQUIRED_FIELDS = URL_FIELDS + INTEGER_FIELDS + BASE64_FIELDS

      attr_accessor *REQUIRED_FIELDS
      attr_accessor :save_token_async_api_iframe # optional
      attr_accessor :signing_private_key
      alias :origin :issuer

      # optional field
      attr_accessor :icon_152px

      # Used to serve content at /.well-known/delegated-account-recovery/configuration
      def to_h
        {
          "issuer" => self.issuer,
          "countersign-pubkeys-secp256r1" => self.countersign_pubkeys_secp256r1.dup,
          "token-max-size" => self.token_max_size,
          "save-token" => self.save_token,
          "recover-account" => self.recover_account,
          "save-token-async-api-iframe" => self.save_token_async_api_iframe,
          "privacy-policy" => self.privacy_policy
        }
      end

      # The CryptoHelper defines an `unseal` method that requires us to define
      # a `unseal_keys` method that will return the set of keys that are valid
      # when verifying the signature on a sealed key.
      def unseal_keys
        countersign_pubkeys_secp256r1
      end

      # The URL representing the location of the token. Used to initiate a recovery.
      #
      # token_id: the shared ID representing a token.
      def recovery_url(token_id)
        [self.recover_account, "?token_id=", URI.escape(token_id)].join
      end

      # Takes a binary representation of a token and signs if for a given
      # account provider. Do not pass in a RecoveryToken object. The wrapping
      # data structure is identical to the structure it's wrapping in format.
      #
      # token: the to_binary_s or binary representation of the recovery token
      #
      # returns a Base64 encoded representation of the countersigned token
      # and the signature over the token.
      def countersign_token(token)
        begin
          account_provider = RecoveryToken.account_provider_issuer(token)
        rescue RecoveryTokenSerializationError, UnknownProviderError
          raise TokenFormatError, "Could not determine provider"
        end

        counter_recovery_token = RecoveryToken.build(
          issuer: self,
          audience: account_provider,
          type: COUNTERSIGNED_RECOVERY_TOKEN_TYPE
        )

        counter_recovery_token.data = token
        seal(counter_recovery_token)
      end

      # Validate the token according to the processing instructions for the
      # save-token endpoint.
      #
      # Returns a validated token
      def validate_recovery_token!(token)
        errors = []

        # 1. Authenticate the User. The exact nature of how the Recovery Provider authenticates the User is beyond the scope of this specification.
        # handled in before_filter

        # 4. Retrieve the Account Provider configuration as described in Section 2 using the issuer field of the token as the subject.
        begin
          account_provider = RecoveryToken.account_provider_issuer(token)
        rescue RecoveryTokenSerializationError, UnknownProviderError, TokenFormatError => e
          raise RecoveryTokenError, "Could not determine provider: #{e.message}"
        end

        # 2. Parse the token.
        # 3. Validate that the version value is 0.
        # 5. Validate the signature over the token according to processing rules for the algorithm implied by the version.
        begin
          recovery_token = account_provider.unseal(token)
        rescue CryptoError => e
          raise RecoveryTokenError.new("Unable to verify signature of token")
        rescue TokenFormatError => e
          raise RecoveryTokenError.new(e.message)
        end

        # 6. Validate that the audience field of the token identifies an origin which the provider considers itself authoritative for. (Often the audience will be same-origin with the Recovery Provider, but other values may be acceptable, e.g. "https://mail.example.com" and "https://social.example.com" may be acceptable audiences for "https://recovery.example.com".)
        unless self.origin == recovery_token.audience
          raise RecoveryTokenError.new("Unnacceptable audience")
        end

        if DateTime.parse(recovery_token.issued_time).utc < CLOCK_SKEW.ago.utc
          raise RecoveryTokenError.new("Issued at time is too far in the past")
        end

        recovery_token
      end
    end
  end
end
