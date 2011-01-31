$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)

require 'rubygems'
require 'bundler'
require "rspec/core/rake_task"
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "dynashard"
  gem.homepage = "http://github.com/nickh/dynashard"
  gem.license = "MIT"
  gem.summary = 'Dynamic sharding for ActiveRecord'
  gem.description = 'Dynashard allows you to shard your ActiveRecord models.  Models can be configured to shard based on context that can be defined dynamically.'
  gem.email = "nickh@verticalresponse.com"
  gem.authors = ["Nick Hengeveld"]
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
  gem.add_runtime_dependency 'activerecord', '>= 3.0'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "dynashard #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
