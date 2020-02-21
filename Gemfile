# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "activerecord"
gem "dalli"
gem "rack_csrf"
gem "rake"
gem "sinatra"
gem "sinatra-activerecord"
gem "sinatra-contrib"

group :development do
  gem "jdbc-sqlite3", platform: :jruby
  gem "pry-nav"
  gem "sqlite3", platform: [:ruby, :mswin, :mingw]
end

group :test do
  gem "database_cleaner"
  gem "guard-rspec"
  gem "mechanize"
  gem "poltergeist"
  gem "rspec"
  gem "rubocop", "< 0.68"
  gem "rubocop-github"
  gem "rubocop-performance"
  gem "ruby_gntp"
  gem "simplecov"
  gem "simplecov-json"
  gem "vcr"
  gem "watir"
  gem "webmock"
end

group :production do
  gem "pg"
end
