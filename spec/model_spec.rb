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
      context 'when managing sharded models' do
        before(:each) do
          @shard1_klass = Dynashard.class_for('shard1')
          @shard2_klass = Dynashard.class_for('shard2')
          @shard1_subclass = Dynashard.sharded_model_class(@shard1_klass, ShardedHasOne)
          @shard2_subclass = Dynashard.sharded_model_class(@shard2_klass, ShardedHasOne)
        end

        it 'uses the sharded connection for the model class' do
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

        it 'associates new models with the correct shard' do
          new1 = Dynashard.with_context(:owner => 'shard1') {ShardedHasOne.new(:name => Factory.next(:name))}
          new2 = Dynashard.with_context(:owner => 'shard2') {ShardedHasOne.new(:name => Factory.next(:name))}
          new1.should be_a(@shard1_subclass)
          new2.should be_a(@shard2_subclass)
          new1.connection.should == @shard1_klass.connection
          new2.connection.should == @shard2_klass.connection
        end

        it 'associates created models with the correct shard' do
          created1 = Dynashard.with_context(:owner => 'shard1') {ShardedHasOne.create(:name => Factory.next(:name))}
          created2 = Dynashard.with_context(:owner => 'shard2') {ShardedHasOne.create(:name => Factory.next(:name))}
          created1.should be_a(@shard1_subclass)
          created2.should be_a(@shard2_subclass)
          created1.connection.should == @shard1_klass.connection
          created2.connection.should == @shard2_klass.connection
        end

        it 'associates loaded models with the correct shard' do
          model1 = Dynashard.with_context(:owner => 'shard1') {Factory(:sharded_has_one)}
          model2 = Dynashard.with_context(:owner => 'shard2') {Factory(:sharded_has_one)}
          found1 = Dynashard.with_context(:owner => 'shard1') {ShardedHasOne.find(model1.id)}
          found2 = Dynashard.with_context(:owner => 'shard2') {ShardedHasOne.find(model2.id)}
          found1.should be_a(@shard1_subclass)
          found2.should be_a(@shard2_subclass)
          found1.connection.should == @shard1_klass.connection
          found2.connection.should == @shard2_klass.connection
        end
      end
    end
  end
end
