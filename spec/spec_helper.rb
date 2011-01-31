$:.unshift(File.dirname(__FILE__) + '/../lib')
plugin_test_dir = File.dirname(__FILE__)

require 'rubygems'
require 'bundler/setup'
require 'erb'

require 'rspec'
require 'logger'

require 'active_record'
require 'factory_girl_rails'

require 'dynashard'

ActiveRecord::Base.logger = Logger.new(plugin_test_dir + "/debug.log")

ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read(plugin_test_dir + "/db/database.yml")).result(binding))
ActiveRecord::Base.establish_connection("test")
ActiveRecord::Migration.verbose = false

test_database = ActiveRecord::Base.configurations['test']['database']
File.unlink(test_database) if File.exists?(test_database)
load(File.join(plugin_test_dir, "db", "schema.rb"))

# create shards and databases that they point to
base_config = ActiveRecord::Base.configurations['test']
%w{shard1 shard2 shard3}.each do |shard|
  database = "#{plugin_test_dir}/db/#{shard}.sqlite3"
  File.unlink(database) if File.exists?(database)
  shard_config = base_config.merge('database' => database)
  ActiveRecord::Base.configurations['test'] = shard_config
  ActiveRecord::Base.establish_connection("test")
  load(File.join(plugin_test_dir, "db", "schema.rb"))
end
ActiveRecord::Base.configurations['test'] = base_config
ActiveRecord::Base.establish_connection("test")

require 'support/models'

%w{shard1 shard2 shard3}.each do |shard|
  Shard.create(:adapter => 'sqlite3', :database => "#{plugin_test_dir}/db/#{shard}.sqlite3")
end

# This has to happen after the models have been defined and the shards have been created
require 'support/factories'
