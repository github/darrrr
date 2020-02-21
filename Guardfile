# frozen_string_literal: true

guard :rspec, cmd: "bundle exec rspec", all_after_pass: true do
  require "guard/rspec/dsl"
  dsl = Guard::RSpec::Dsl.new(self)

  # RSpec files
  rspec = dsl.rspec
  watch(rspec.spec_helper) { rspec.spec_dir }
  watch(rspec.spec_support) { rspec.spec_dir }
  watch(rspec.spec_files)
  watch("lib/darrrr/provider.rb") {
    %w(
      spec/lib/darrrr/account_provider_spec.rb
      spec/lib/darrrr/recovery_provider_spec.rb
      spec/lib/integration/account_provider_controller_spec.rb
      spec/lib/integration/recovery_provider_controller_spec.rb
    )
  }
  dsl.watch_spec_files_for(dsl.ruby.lib_files)
end
