require 'spec_helper'

describe 'Dynashard::ConnectionHandlerExtensions' do
  before(:each) do
    Dynashard.enable
  end

  context 'defining connection pool aliases' do
    after(:each) do
      ActiveRecord::Base.connection_handler.connection_pools.delete('Foo')
    end

    it 'succeeds' do
      connection_handler = ActiveRecord::Base.connection_handler
      connection_handler.dynashard_pool_alias('Foo', 'ActiveRecord::Base')
      connection_handler.connection_pools['Foo'].should == connection_handler.connection_pools['ActiveRecord::Base']
    end
  end

  context 'with a sharded association reflection' do
    it 'retrieves the connection pool' do
      owner = Factory(:sharding_owner)
      reflection = Dynashard.reflection_for(owner, ShardingOwner.reflections[:sharded_has_one])
      dynashard_klass = reflection.klass.dynashard_klass
      pool = ActiveRecord::Base.connection_handler.connection_pools['ActiveRecord::Base']
      ActiveRecord::Base.connection_handler.should_receive(:retrieve_connection_pool_without_dynashard).with(dynashard_klass).and_return(pool)
      reflection.klass.connection.should be_kind_of(ActiveRecord::ConnectionAdapters::AbstractAdapter)
    end
  end

  context 'with a sharded model' do
    before(:each) do
      @shard_klass = Dynashard.class_for('shard1')
    end

    it 'retrieves the connection' do
      dsn = Shard.find(:first).dsn
      shard_klass = Dynashard.class_for(dsn)
      pool = ActiveRecord::Base.connection_handler.connection_pools['ActiveRecord::Base']
      ActiveRecord::Base.connection_handler.should_receive(:retrieve_connection_pool_without_dynashard).with(shard_klass).and_return(pool)
      connection = Dynashard.with_context(:owner => dsn) {ShardedHasOne.connection}
      connection.should be_kind_of(ActiveRecord::ConnectionAdapters::AbstractAdapter)
    end

    it 'requires a defined shard context' do
      Dynashard.shard_context.clear
      ShardedHasOne.sharding_enabled?.should be_true
      lambda do
        connection = ShardedHasOne.find(:first)
      end.should raise_error(RuntimeError)
    end
  end

  context 'with a non-sharded model' do
    it 'retrieves the connection' do
      pool = ActiveRecord::Base.connection_handler.connection_pools['ActiveRecord::Base']
      ActiveRecord::Base.connection_handler.should_receive(:retrieve_connection_pool_without_dynashard).with(NonShardedHasOne).and_return(pool)
      NonShardedHasOne.connection.should be_kind_of(ActiveRecord::ConnectionAdapters::AbstractAdapter)
    end
  end
end
