# Sequence for generating unique names
Factory.sequence :name do |n|
  "Test Name #{n}"
end

Factory.define(:sharding_owner) do |owner|
  owner.name {Factory.next :name}
  owner.shard Shard.find(:first)
end

Factory.define(:non_sharding_owner) do |owner|
  owner.name {Factory.next :name}
end

Factory.define(:sharded_has_one) do |one|
  one.name {Factory.next :name}
  one.sharding_owner
end

Factory.define(:sharded_has_many) do |one_of_many|
  one_of_many.name {Factory.next :name}
  one_of_many.sharding_owner
end

Factory.define(:sharded_join) do |join|
  join.sharding_owner
  join.sharded_has_many_through
end

Factory.define(:sharded_has_many_through) do |one_of_many|
  one_of_many.name {Factory.next :name}
end

Factory.define(:sharded_habtm) do |habtm|
  habtm.name {Factory.next :name}
end
