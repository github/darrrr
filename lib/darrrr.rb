require "active_support/time"
require "bindata"
require "openssl"
require "addressable"
require "forwardable"
require "faraday"

require_relative "github/delegated_account_recovery"

Darrrr = GitHub::DelegatedAccountRecovery
