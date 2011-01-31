class Shard < ActiveRecord::Base
  def dsn
    HashWithIndifferentAccess.new(self.attributes.reject{|k,v| v.nil? || ['name','id'].include?(k)})
  end
end

# Owner class that doesn't shard its associations
class NonShardingOwner < ActiveRecord::Base
  # Non-sharded associations
  has_one :non_sharded_has_one
  has_many :non_sharded_has_manys
  has_many :non_sharded_joins
  has_many :non_sharded_has_many_throughs, :through => :non_sharded_joins

  # Sharded associations
  has_one :sharded_has_one
  has_many :sharded_has_manys
  has_many :sharded_joins
  has_many :sharded_has_many_throughs, :through => :sharded_joins
end

# Owner class for sharded associations
class ShardingOwner < ActiveRecord::Base
  shard :associated, :using => :shard_dsn

  belongs_to :shard
  def shard_dsn
    @dsn ||= shard.dsn
  end

  # Non-sharded associations
  has_one :non_sharded_has_one
  has_many :non_sharded_has_manys
  has_many :non_sharded_joins
  has_many :non_sharded_has_many_throughs, :through => :non_sharded_joins

  # Sharded associations
  has_one :sharded_has_one
  has_many :sharded_has_manys
  has_many :sharded_joins
  has_many :sharded_has_many_throughs, :through => :sharded_joins
end

# Non-sharded has_one association class
class NonShardedHasOne < ActiveRecord::Base
  belongs_to :sharding_owner

  validates :name, :uniqueness => true
end

# Non-sharded has_many association class
class NonShardedHasMany < ActiveRecord::Base
  belongs_to :sharding_owner
  belongs_to :non_sharding_owner
end

# Join table for has_many :through
class NonShardedJoin < ActiveRecord::Base
  belongs_to :sharding_owner
  belongs_to :non_sharded_has_many_through
end

# Non-sharded has_many association class
class NonShardedHasManyThrough < ActiveRecord::Base
  has_many :non_sharded_joins
end

# Sharded has_one association class
class ShardedHasOne < ActiveRecord::Base
  shard :by => :owner

  validates :name, :uniqueness => true

  belongs_to :sharding_owner
  belongs_to :non_sharding_owner
end

# Sharded has_many association class
class ShardedHasMany < ActiveRecord::Base
  shard :by => :owner

  belongs_to :sharding_owner
  belongs_to :non_sharding_owner
end

# Join table for has_many :through
class ShardedJoin < ActiveRecord::Base
  shard :by => :owner

  belongs_to :sharding_owner
  belongs_to :sharded_has_many_through
end

# Sharded has_many :through association class
class ShardedHasManyThrough < ActiveRecord::Base
  shard :by => :owner

  has_many :sharded_joins
end
