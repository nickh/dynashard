require 'spec_helper'

describe 'Dynashard::ProxyExtensions' do
  before(:each) do
    Dynashard.enable
  end

  context 'with a sharding proxy owner' do
    before(:each) do
      @owner = Factory(:sharding_owner)
      @shard = @owner.shard_dsn
    end

    context 'and a sharding proxy target' do
      it 'uses a sharded reflection class' do
        orig_reflection = @owner.class.reflections[:sharded_has_manys]
        new_reflection  = Dynashard.reflection_for(@owner, orig_reflection)
        Dynashard.should_receive(:reflection_for).once.and_return(new_reflection)
        proxy = @owner.sharded_has_manys
        proxy.proxy_reflection.klass.dynashard_klass.should_not be_nil
        proxy.proxy_reflection.should == new_reflection
      end

      context 'using a :has_one reflection' do
        before(:each) do
          # Ensure that all sharded model connections happen on the owner shard
          Dynashard.shard_context[:owner] = @shard

          @has_one = Factory(:sharded_has_one, :sharding_owner => @owner, :name => "Owned by #{@owner.name}")
        end

        after(:each) do
          Dynashard.shard_context.clear
        end

        # TODO: figure out what to do about the classes being different
        it 'reads from the shard' do
          @owner.sharded_has_one.attributes.should == @has_one.attributes
        end

        it 'destroys from the shard' do
          lambda do
            @owner.sharded_has_one.destroy
          end.should change(ShardedHasOne, :count).by(-1)
        end

        it 'creates_other on the shard' do
          new_owner = Factory(:sharding_owner, :shard => @owner.shard)
          lambda do
            new_owner.create_sharded_has_one(:name => "Owned by #{new_owner.name}")
          end.should change(ShardedHasOne, :count).by(1)
        end

        it 'saves built associations on the shard' do
          new_owner = Factory(:sharding_owner, :shard => @owner.shard)
          new_sharded_has_one = new_owner.build_sharded_has_one(:name => "Owned by #{new_owner.name}")
          lambda do
            new_sharded_has_one.save
          end.should change(ShardedHasOne, :count).by(1)
        end
      end

      context 'using a :has_many reflection' do
        before(:each) do
          # Ensure that all sharded model connections happen on the owner shard
          Dynashard.shard_context[:owner] = @shard

          @one_of_many = Factory(:sharded_has_many, :sharding_owner => @owner, :name => "Owned by #{@owner.name}")
        end

        after(:each) do
          Dynashard.shard_context.clear
        end

        # TODO: figure out what to do about the classes being different
        it 'reads from the shard' do
          @owner.sharded_has_manys.detect{|m| m.attributes == @one_of_many.attributes}.should_not be_nil
        end

        it 'destroys from the shard' do
          lambda do
            one_of_many = @owner.sharded_has_manys.detect{|m| m.attributes == @one_of_many.attributes}
            one_of_many.destroy
          end.should change(ShardedHasMany, :count).by(-1)
        end

        it 'creates_other on the shard' do
          new_owner = Factory(:sharding_owner, :shard => @owner.shard)
          lambda do
            new_owner.sharded_has_manys.create(:name => "Owned by #{new_owner.name}")
          end.should change(ShardedHasMany, :count).by(1)
        end

        it 'saves built associations on the shard' do
          new_owner = Factory(:sharding_owner, :shard => @owner.shard)
          new_one_of_many = new_owner.sharded_has_manys.build(:name => "Owned by #{new_owner.name}")
          lambda do
            new_one_of_many.save
          end.should change(ShardedHasMany, :count).by(1)
        end
      end

      context 'using a :has_many_through reflection' do
        before(:each) do
          # Ensure that all sharded model connections happen on the owner shard
          Dynashard.shard_context[:owner] = @shard

          @one_of_many = Factory(:sharded_has_many_through, :name => "Owned by #{@owner.name}")
          join = Factory(:sharded_join, :sharding_owner => @owner, :sharded_has_many_through => @one_of_many)
        end

        after(:each) do
          Dynashard.shard_context.clear
        end

        # TODO: figure out what to do about the classes being different
        it 'reads from the shard' do
          @owner.sharded_has_many_throughs.detect{|m| m.attributes == @one_of_many.attributes}.should_not be_nil
        end

        it 'destroys from the shard' do
          lambda do
            one_of_many = @owner.sharded_has_many_throughs.detect{|m| m.attributes == @one_of_many.attributes}
            one_of_many.destroy
          end.should change(ShardedHasManyThrough, :count).by(-1)
        end

        it 'creates_other on the shard' do
          new_owner = Factory(:sharding_owner, :shard => @owner.shard)
          lambda do
            new_owner.sharded_has_many_throughs.create(:name => "Owned by #{new_owner.name}")
          end.should change(ShardedHasManyThrough, :count).by(1)
        end

        it 'saves built associations on the shard' do
          new_owner = Factory(:sharding_owner, :shard => @owner.shard)
          new_one_of_many = new_owner.sharded_has_many_throughs.build(:name => "Owned by #{new_owner.name}")
          lambda do
            new_one_of_many.save
          end.should change(ShardedHasManyThrough, :count).by(1)
        end
      end
    end

    context 'and a non-sharding proxy target' do
      it 'uses a non-sharded reflection class' do
        orig_reflection = @owner.class.reflections[:non_sharded_has_manys]
        Dynashard.should_receive(:reflection_for).never
        proxy = @owner.non_sharded_has_manys
        proxy.proxy_reflection.klass.should_not respond_to(:dynashard_klass)
        proxy.proxy_reflection.should == orig_reflection
      end
    end

  end

  context 'with a non-sharding proxy owner' do
    before(:each) do
      @owner = Factory(:non_sharding_owner)
    end

    context 'and a sharding proxy target' do
      it 'uses a non-sharded reflection class' do
        orig_reflection = @owner.class.reflections[:sharded_has_manys]
        Dynashard.should_receive(:reflection_for).never
        proxy = Dynashard.with_context(:owner => Shard.find(:first).dsn){@owner.sharded_has_manys}
        proxy.proxy_reflection.klass.should_not respond_to(:dynashard_klass)
        proxy.proxy_reflection.should == orig_reflection
      end
    end

    context 'and a non-sharding proxy target' do
      it 'uses a non-sharded reflection class' do
        orig_reflection = @owner.class.reflections[:non_sharded_has_manys]
        Dynashard.should_receive(:reflection_for).never
        proxy = @owner.non_sharded_has_manys
        proxy.proxy_reflection.klass.should_not respond_to(:dynashard_klass)
        proxy.proxy_reflection.should == orig_reflection
      end
    end
  end
end
