# frozen_string_literal: true

require "sinatra"
require "sinatra/multi_route"
require "rack/csrf"
require "json"
require "base64"
require "sinatra/activerecord"
require "pry-nav" if ENV["RACK_ENV"] == "development"
require "dalli"
require "json"

require_relative "lib/darrrr"
require_relative "config/initializers/delegated_account_recovery"

class MainController < Sinatra::Base
  ACCOUNT_PROVIDER_PATH = "/account-provider"
  RECOVERY_PROVIDER_PATH = "/recovery-provider"

  UNAUTHED_ENDPOINTS = [
    "POST:/.well-known/delegated-account-recovery/token-status",
    "POST:#{ACCOUNT_PROVIDER_PATH}/recover-account-return",
    "POST:#{ACCOUNT_PROVIDER_PATH}/save-token-return",
    "POST:#{RECOVERY_PROVIDER_PATH}/recover-account",
    "POST:#{RECOVERY_PROVIDER_PATH}/save-token",
  ]

  register Sinatra::MultiRoute
  register Sinatra::ActiveRecordExtension

  before do
    unless request.ssl?
      halt 401, "Not authorized\n" if ENV["RACK_ENV"] == :production
    end
  end

  def notify(message, provider)
    # send out of band notifications via email, sms, in-app notifications, smoke signals
  end

  def audit(message, token_id)
    # allow users and staff to easily verify history
  end
end
