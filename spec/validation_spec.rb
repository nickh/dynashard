require 'spec_helper'

describe 'Dynashard::ValidationExtensions' do
  before(:each) do
    @owner = Factory(:sharding_owner)
  end

  describe '#find_finder_class_for' do
    before(:each) do
      @shard_klass = Dynashard.class_for(@owner.shard_dsn)
      @sharded_model_subclass = Dynashard.sharded_model_class(@shard_klass, ShardedHasOne)
    end

    context 'when sharding' do
      before(:each) do
        @validator = ShardedHasOne.validators.detect{|v| v.is_a?(ActiveRecord::Validations::UniquenessValidator)}
      end

      context 'with a generated association owner class' do
        it 'returns the generated class' do
          new_record = @owner.build_sharded_has_one
          @validator.send(:find_finder_class_for, new_record).should == @sharded_model_subclass
        end
      end

      context 'with a model class' do
        it 'returns the generated shard subclass' do
          Dynashard.with_context(:owner => @owner.shard_dsn) do
            new_record = ShardedHasOne.new
            @validator.send(:find_finder_class_for, new_record).should == @sharded_model_subclass
          end
        end
      end
    end

    context 'when not sharding' do
      before(:each) do
        @validator = NonShardedHasOne.validators.detect{|v| v.is_a?(ActiveRecord::Validations::UniquenessValidator)}
      end

      context 'with a non-sharding association owner class' do
        it 'returns the model class' do
          non_sharding_owner = Factory(:non_sharding_owner)
          new_record = non_sharding_owner.build_non_sharded_has_one
          @validator.send(:find_finder_class_for, new_record).should == NonShardedHasOne
        end
      end

      context 'with a non-sharding model class' do
        it 'returns the model class' do
          new_record = NonShardedHasOne.new
          @validator.send(:find_finder_class_for, new_record).should == NonShardedHasOne
        end
      end
    end
  end

  context 'when validating uniqueness' do
    context 'with an association proxy target' do
      context 'with a conflicting record on the shard' do
        it 'returns invalid' do
          conflicting_record = Dynashard.with_context(:owner => @owner.shard_dsn){Factory(:sharded_has_one)}
          new_record = @owner.build_sharded_has_one(:name => conflicting_record.name)
          new_record.should_not be_valid
        end
      end

      context 'with a conflicting record on a different shard' do
        it 'returns valid' do
          other_shard = Shard.find(:all).detect{|shard| shard != @owner.shard}
          non_conflicting_record = Dynashard.with_context(:owner => other_shard.dsn){Factory(:sharded_has_one)}
          new_record = @owner.build_sharded_has_one(:name => non_conflicting_record.name)
          new_record.should be_valid
        end
      end
    end

    context 'with a model class' do
      context 'with a conflicting record on the shard' do
        it 'returns invalid' do
          conflicting_record = Dynashard.with_context(:owner => @owner.shard_dsn){Factory(:sharded_has_one)}
          Dynashard.with_context(:owner => @owner.shard_dsn) do
            ShardedHasOne.new(:name => conflicting_record.name).should_not be_valid
          end
        end
      end

      context 'with a conflicting record on a different shard' do
        it 'returns valid' do
          other_shard = Shard.find(:all).detect{|shard| shard != @owner.shard}
          non_conflicting_record = Dynashard.with_context(:owner => other_shard.dsn){Factory(:sharded_has_one)}
          Dynashard.with_context(:owner => @owner.shard_dsn) do
            ShardedHasOne.new(:name => non_conflicting_record.name).should be_valid
          end
        end
      end
    end
  end
end
