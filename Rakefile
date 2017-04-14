#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'net/http'
require 'net/https'
require 'date'

require_relative "app"
require_relative "lib/darrrr"
require "sinatra/activerecord/rake"

namespace :db do
  task :load_config do
    require "./app"
  end
end


unless ENV["RACK_ENV"] == "production"
  require 'rspec/core/rake_task'
  desc "Run RSpec"
  RSpec::Core::RakeTask.new do |t|
    t.verbose = false
    t.rspec_opts = "--format progress"
  end

  task default: :spec
end

begin
  require 'rdoc/task'
rescue LoadError
  require 'rdoc/rdoc'
  require 'rake/rdoctask'
  RDoc::Task = Rake::RDocTask
end

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'SecureHeaders'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('lib/**/*.rb')
end
