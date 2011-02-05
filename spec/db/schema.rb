ActiveRecord::Schema.define(:version => 1) do

  create_table "shards", :force => true do |t|
    t.string  "name"
    t.string  "adapter"
    t.string  "host"
    t.string  "username"
    t.string  "password"
    t.string  "database"
    t.integer "port"
    t.integer "pool"
    t.integer "timeout"
  end

  create_table "non_sharding_owners", :force => true do |t|
    t.string "name"
  end
  add_index :non_sharding_owners, :name, :unique => true

  create_table "sharding_owners", :force => true do |t|
    t.string  "name"
    t.integer "shard_id"
  end
  add_index :sharding_owners, :name, :unique => true

  create_table "non_sharded_has_ones", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.string  "name"
  end
  add_index :non_sharded_has_ones, :name, :unique => true

  create_table "non_sharded_has_manies", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.string  "name"
  end
  add_index :non_sharded_has_manies, :name, :unique => true

  create_table "non_sharded_joins", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.integer "non_sharded_has_many_through_id"
  end

  create_table "non_sharded_has_many_throughs", :force => true do |t|
    t.string  "name"
  end
  add_index :non_sharded_has_many_throughs, :name, :unique => true

  create_table "sharded_has_ones", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.string  "name"
  end
  add_index :sharded_has_ones, :name, :unique => true

  create_table "sharded_has_manies", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.string  "name"
  end
  add_index :sharded_has_manies, :name, :unique => true

  create_table "sharded_joins", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.integer "sharded_has_many_through_id"
  end

  create_table "sharded_has_many_throughs", :force => true do |t|
    t.string  "name"
  end
  add_index :sharded_has_many_throughs, :name, :unique => true

  create_table "sharded_dependent_joins", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.integer "sharded_dependent_has_many_through_id"
  end

  create_table "sharded_dependent_has_many_throughs", :force => true do |t|
    t.string  "name"
  end
  add_index :sharded_dependent_has_many_throughs, :name, :unique => true

  # create_table "sharded_habtms_sharding_owners", :id => false  # doesn't seem to create a schema without an ID...
  connection.execute('CREATE TABLE "sharded_habtms_sharding_owners" ("sharded_habtm_id" integer, "sharding_owner_id" integer)')

  create_table "sharded_habtms", :force => true do |t|
    t.string "name"
  end
  add_index :sharded_habtms, :name, :unique => true
end
