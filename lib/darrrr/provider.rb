# frozen_string_literal: true

module Darrrr
  module Provider
    RECOVERY_PROVIDER_CACHE_LENGTH = 60.seconds
    MAX_RECOVERY_PROVIDER_CACHE_LENGTH = 5.minutes
    REQUIRED_CRYPTO_OPS = [:sign, :verify, :encrypt, :decrypt].freeze
    include Constants

    def self.included(base)
      base.instance_eval do
        attr_accessor :faraday_config_callback
        # this represents the account/recovery provider on this web app
        class << self
          attr_accessor :this

          def configure(&block)
            raise ArgumentError, "Block required to configure #{self.name}" unless block_given?
            raise ProviderConfigError, "#{self.name} already configured" if self.this
            self.this = self.new.tap { |provider| provider.instance_eval(&block).freeze }
            self.this.privacy_policy = Darrrr.privacy_policy
            self.this.icon_152px = Darrrr.icon_152px
            self.this.issuer = Darrrr.authority
          end
        end
      end
    end

    def initialize(provider_origin = nil, attrs: nil)
      self.issuer = provider_origin
      load(attrs) if attrs
    end

    # Returns the crypto API to be used. A thread local instance overrides the
    # globally configured value which overrides the default encryptor.
    def encryptor
      Thread.current[encryptor_key()] || @encryptor || DefaultEncryptor
    end

    # Overrides the global `encryptor` API to use
    #
    # encryptor: a class/module that responds to all +REQUIRED_CRYPTO_OPS+.
    def custom_encryptor=(encryptor)
      if valid_encryptor?(encryptor)
        @encryptor = encryptor
      else
        raise ArgumentError, "custom encryption class must respond to all of #{REQUIRED_CRYPTO_OPS}"
      end
    end

    def with_encryptor(encryptor)
      raise ArgumentError, "A block must be supplied" unless block_given?
      unless valid_encryptor?(encryptor)
        raise ArgumentError, "custom encryption class must respond to all of #{REQUIRED_CRYPTO_OPS}"
      end

      Thread.current[encryptor_key()] = encryptor
      yield
    ensure
      Thread.current[encryptor_key()] = nil
    end

    private def valid_encryptor?(encryptor)
      REQUIRED_CRYPTO_OPS.all? {|m| encryptor.respond_to?(m)}
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
        if @faraday_config_callback
          @faraday_config_callback.call(f)
        else
          f.adapter(Faraday.default_adapter)
        end
      end
    end

    private def cache_config(response)
      match = /max-age=(\d+)/.match(response.headers["cache-control"])
      cache_age = if match
        [match[1].to_i, MAX_RECOVERY_PROVIDER_CACHE_LENGTH].min
      else
        RECOVERY_PROVIDER_CACHE_LENGTH
      end
      Darrrr.cache.try(:set, cache_key, response.body, cache_age)
    end

    private def cache_key
      "recovery_provider_config:#{self.origin}:configuration"
    end

    private def fetch_config!
      unless body = Darrrr.cache.try(:get, cache_key)
        response = faraday.get([self.origin, Darrrr::WELL_KNOWN_CONFIG_PATH].join("/"))
        if response.success?
          cache_config(response)
        else
          raise ProviderConfigError.new("Unable to retrieve recovery provider config for #{self.origin}: #{response.status}: #{response.body[0..100]}")
        end

        body = response.body
      end

      JSON.parse(body)
    rescue ::JSON::ParserError
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
          if !Darrrr.allow_unsafe_urls && uri.try(:scheme) != "https"
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
