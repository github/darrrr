source 'https://rubygems.org'

gemspec

gem "activerecord"
gem "rack_csrf"
gem "sinatra-activerecord"
gem "rake"
gem "sinatra"
gem "sinatra-contrib"
gem "dalli"

group :development do
  gem "pry-nav"
  gem "jdbc-sqlite3", :platform => :jruby
  gem "sqlite3", :platform => [:ruby, :mswin, :mingw]
end

group :test do
  gem "mechanize"
  gem "watir"
  gem "vcr"
  gem "webmock"
  gem "rspec"
  gem "guard-rspec"
  gem "ruby_gntp"
  gem "poltergeist"
  gem "simplecov"
  gem "simplecov-json"
  gem "database_cleaner"
end

group :production do
  gem "pg"
end
