# coding: utf-8
require_relative "lib/github/delegated_account_recovery/version"

Gem::Specification.new do |gem|
  gem.name    = "darrrr"
  gem.version = GitHub::DelegatedAccountRecovery::VERSION

  gem.summary = "Client library for the Delegated Recovery spec"
  gem.description = "See https://www.facebook.com/notes/protect-the-graph/improving-account-security-with-delegated-recovery/1833022090271267/"

  gem.authors  = ["Neil Matatall"]
  gem.email    = "opensource+darrrr@github.com"
  gem.homepage = "http://github.com/oreoshake/darrrr"

  gem.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  gem.bindir        = "exe"
  gem.require_paths = ["lib"]

  gem.add_dependency("rake")
  gem.add_dependency("bindata")
  gem.add_dependency("faraday")
  gem.add_dependency("addressable")
  gem.add_dependency("multi_json")

  gem.files = Dir["Rakefile", "{lib}/**/*", "README*", "LICENSE*"] & `git ls-files -z`.split("\0")
end
