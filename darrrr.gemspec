# coding: utf-8
# frozen_string_literal: true

Gem::Specification.new do |gem|
  gem.name    = "darrrr"
  gem.version = "0.1.5"
  gem.licenses = ["MIT"]

  gem.summary = "Client library for the Delegated Recovery spec"
  gem.description = "See https://www.facebook.com/notes/protect-the-graph/improving-account-security-with-delegated-recovery/1833022090271267/"

  gem.authors  = ["Neil Matatall"]
  gem.email    = "opensource+darrrr@github.com"
  gem.homepage = "http://github.com/github/darrrr"

  gem.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  gem.bindir        = "exe"
  gem.require_paths = ["lib"]

  gem.add_dependency("rake")
  if RUBY_VERSION > "2.6"
    gem.add_dependency("bindata", ">= 2.4.6") # See https://github.com/dmendel/bindata/pull/120
  else
    gem.add_dependency("bindata")
  end
  gem.add_dependency("faraday")
  gem.add_dependency("addressable")

  gem.files = Dir["Rakefile", "{lib}/**/*", "README*", "LICENSE*"] & `git ls-files -z`.split("\0")
end
