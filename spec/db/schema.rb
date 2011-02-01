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

  create_table "sharding_owners", :force => true do |t|
    t.string  "name"
    t.integer "shard_id"
  end

  create_table "non_sharded_has_ones", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.string  "name"
  end

  create_table "non_sharded_has_manies", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.string  "name"
  end

  create_table "non_sharded_joins", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.integer "non_sharded_has_many_through_id"
  end

  create_table "non_sharded_has_many_throughs", :force => true do |t|
    t.string  "name"
  end

  create_table "sharded_has_ones", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.string  "name"
  end

  create_table "sharded_has_manies", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.string  "name"
  end

  create_table "sharded_joins", :force => true do |t|
    t.integer "sharding_owner_id"
    t.integer "non_sharding_owner_id"
    t.integer "sharded_has_many_through_id"
  end

  create_table "sharded_has_many_throughs", :force => true do |t|
    t.string  "name"
  end
end
