# frozen_string_literal: true

module GitHub
  module DelegatedAccountRecovery
    module Provider
      RECOVERY_PROVIDER_CACHE_LENGTH = 60.seconds
      MAX_RECOVERY_PROVIDER_CACHE_LENGTH = 5.minutes
      include Constants

      def self.included(base)
        base.instance_eval do
          # this represents the account/recovery provider on this web app
          class << self
            attr_accessor :this

            def configure(&block)
              raise ArgumentError, "Block required to configure #{self.name}" unless block_given?
              raise ProviderConfigError, "#{self.name} already configured" if self.this
              self.this = self.new.tap { |provider| provider.instance_eval(&block).freeze }
              self.this.privacy_policy = DelegatedAccountRecovery.privacy_policy
              self.this.icon_152px = DelegatedAccountRecovery.icon_152px
              self.this.issuer = DelegatedAccountRecovery.authority
            end
          end
        end
      end

      def initialize(provider_origin = nil, attrs: nil)
        self.issuer = provider_origin
        load(attrs) if attrs
      end

      # Lazily loads attributes if attrs is nil. It makes an http call to the
      # recovery provider's well-known config location and caches the response
      # if it's valid json.
      #
      # attrs: optional way of building the provider without making an http call.
      def load(attrs = nil)
        body = attrs || fetch_config!
        set_attrs!(body)
        self
      end

      private def faraday
        Faraday.new do |f|
          f.adapter(Faraday.default_adapter)
        end
      end

      private def cache_config(response)
        match = /max-age=(\d+)/.match(response.headers["cache-control"])
        cache_age = if match
          [match[1].to_i, MAX_RECOVERY_PROVIDER_CACHE_LENGTH].min
        else
          RECOVERY_PROVIDER_CACHE_LENGTH
        end
        DelegatedAccountRecovery.cache.try(:set, cache_key, response.body, cache_age)
      end

      private def cache_key
        "recovery_provider_config:#{self.origin}:configuration"
      end

      private def fetch_config!
        unless body = DelegatedAccountRecovery.cache.try(:get, cache_key)
          response = faraday.get([self.origin, DelegatedAccountRecovery::WELL_KNOWN_CONFIG_PATH].join("/"))
          if response.success?
            cache_config(response)
          else
            raise ProviderConfigError.new("Unable to retrieve recovery provider config for #{self.origin}: #{response.status}: #{response.body[0..100]}")
          end

          body = response.body
        end

        JSON.parse(body)
      rescue JSON::ParserError
        raise ProviderConfigError.new("Unable to parse recovery provider config for #{self.origin}:#{body[0..100]}")
      end

      private def set_attrs!(context)
        self.class::REQUIRED_FIELDS.each do |attr|
          value = context[attr.to_s.tr("_", "-")]
          self.instance_variable_set("@#{attr}", value)
        end

        if errors.any?
          raise ProviderConfigError.new("Unable to parse recovery provider config for #{self.origin}: #{errors.join(", ")}")
        end
      end

      private def errors
        errors = []
        self.class::REQUIRED_FIELDS.each do |field|
          unless self.instance_variable_get("@#{field}")
            errors << "#{field} not set"
          end
        end

        self.class::URL_FIELDS.each do |field|
          begin
            uri = Addressable::URI.parse(self.instance_variable_get("@#{field}"))
            if !DelegatedAccountRecovery.allow_unsafe_urls && uri.try(:scheme) != "https"
              errors << "#{field} must be an https URL"
            end
          rescue Addressable::URI::InvalidURIError
            errors << "#{field} must be a valid URL"
          end
        end

        if self.is_a? RecoveryProvider
          unless self.token_max_size.to_i > 0
            errors << "token max size must be an integer"
          end
        end

        unless self.unseal_keys.try(:any?)
          errors << "No public key provided"
        end

        errors
      end
    end
  end
end
