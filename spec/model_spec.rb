require 'spec_helper'

describe 'ActiveRecord Models' do

  context 'with invalid sharding arguments' do
    after(:each) do
      Object.send(:remove_const, :DynashardTestClass) if Object.const_defined?(:DynashardTestClass)
    end

    context 'for association owners' do
      it 'raises an exception' do
        lambda do
          class DynashardTestClass < ActiveRecord::Base
            shard :associated, :without_using_arg => true
          end
        end.should raise_error(ArgumentError)
      end
    end

    context 'for sharded models' do
      it 'raises an exception' do
        lambda do
          class DynashardTestClass < ActiveRecord::Base
            shard :without_using_by => true
          end
        end.should raise_error(ArgumentError)
      end
    end
  end

  context 'with Dynashard disabled' do
    before(:each) do
      Dynashard.disable
    end

    after(:each) do
      Dynashard.enable
    end

    it 'uses the ActiveRecord::Base connection' do
      ShardedHasOne.connection.should == ActiveRecord::Base.connection
    end

    it 'do not shard' do
      ShardedHasOne.sharding_enabled?.should be_false
    end

    it 'do not shard associations' do
      ShardingOwner.shards_associated?.should be_false
    end
  end

  context 'with Dynashard enabled' do
    before(:each) do
      Dynashard.enable
    end

    it 'can be sharded' do
      ShardedHasOne.sharding_enabled?.should be_true
    end

    it 'can have sharded associations' do
      ShardingOwner.shards_associated?.should be_true
    end

    it 'shards associations using a specified arg' do
      class DynashardTestClass < ActiveRecord::Base
        shard :associated, :using => :foo
      end
      DynashardTestClass.dynashard_association_using.should == :foo
      Object.send(:remove_const, :DynashardTestClass)
    end

    it 'shards models using a specified context' do
      class DynashardTestClass < ActiveRecord::Base
        shard :by => :foo
      end
      DynashardTestClass.dynashard_context.should == :foo
      Object.send(:remove_const, :DynashardTestClass)
    end

    context 'and no shard context defined' do
      it 'raises an exception' do
        lambda do
          ShardedHasOne.connection
        end.should raise_error
      end
    end

    context 'and the shard context defined' do
      it 'uses the sharded connection' do
        test_shard = 'shard1'
        Dynashard.with_context(:owner => test_shard) do
          shard_class  = Dynashard.class_for(test_shard)
          shard_config = shard_class.connection.instance_variable_get('@config')
          ar_config    = ActiveRecord::Base.connection.instance_variable_get('@config')
          model_config = ShardedHasOne.connection.instance_variable_get('@config')
          model_config.should_not == ar_config
          model_config.should     == shard_config
        end
      end
    end
  end
end
