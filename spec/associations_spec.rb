require 'spec_helper'

class SqlCounter
  def initialize(connection, counter_sql)
    @connection, @counter_sql = connection, counter_sql
  end

  def count
    @connection.execute(@counter_sql).first[0]
  end
end

describe 'Dynashard::ProxyExtensions' do
  before(:each) do
    Dynashard.enable
  end

  context 'with a sharding proxy owner' do
    before(:each) do
      @owner = Factory(:sharding_owner)
      @shard = @owner.shard_dsn
      @shard_klass = Dynashard.class_for(@shard)
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
          @sharded_has_many_through_klass = Dynashard.sharded_model_class(@shard_klass, ShardedHasManyThrough)
          @sharded_join_klass = Dynashard.sharded_model_class(@shard_klass, ShardedJoin)
          @shard_klass.connection.execute("INSERT INTO sharded_has_many_throughs (name) VALUES ('#{Factory.next :name}')")
          one_of_many_id = @shard_klass.connection.execute("SELECT last_insert_rowid()").first[0]
          @shard_klass.connection.execute("INSERT INTO sharded_joins (sharding_owner_id, sharded_has_many_through_id) VALUES (#{@owner.id}, #{one_of_many_id})")
          join_id = @shard_klass.connection.execute("SELECT last_insert_rowid()").first[0]
          @one_of_many = @sharded_has_many_through_klass.find(one_of_many_id)
        end

        it 'reads from the shard' do
          @owner.sharded_has_many_throughs.should include(@one_of_many)
        end

        it 'destroys the model from the shard' do
          lambda {@one_of_many.destroy}.should change(@sharded_has_many_through_klass, :count).by(-1)
        end

        # This class does not have :dependent => :destroy on the join
        it 'leaves the join on the shard' do
          lambda {@one_of_many.destroy}.should_not change(@sharded_join_klass, :count)
        end

        it 'creates_other on the shard' do
          lambda do
            @owner.sharded_has_many_throughs.create(:name => Factory.next(:name))
          end.should change(@sharded_has_many_through_klass, :count).by(1)
        end

        it 'creates joins on the shard' do
          lambda do
            @owner.sharded_has_many_throughs.create(:name => Factory.next(:name))
          end.should change(@sharded_join_klass, :count).by(1)
        end

        it 'saves built associations on the shard' do
          new_one_of_many = @owner.sharded_has_many_throughs.build(:name => Factory.next(:name))
          lambda {@owner.save}.should change(@sharded_has_many_through_klass, :count).by(1)
        end

        it 'saves built association joins on the shard' do
          new_one_of_many = @owner.sharded_has_many_throughs.build(:name => Factory.next(:name))
          lambda {@owner.save}.should change(@sharded_join_klass, :count).by(1)
        end

        context 'with dependent => destroy' do
          before(:each) do
            @sharded_dependent_has_many_through_klass = Dynashard.sharded_model_class(@shard_klass, ShardedDependentHasManyThrough)
            @sharded_dependent_join_klass = Dynashard.sharded_model_class(@shard_klass, ShardedDependentJoin)
            @shard_klass.connection.execute("INSERT INTO sharded_dependent_has_many_throughs (name) VALUES ('#{Factory.next :name}')")
            one_of_many_id = @shard_klass.connection.execute("SELECT last_insert_rowid()").first[0]
            @shard_klass.connection.execute("INSERT INTO sharded_dependent_joins (sharding_owner_id, sharded_dependent_has_many_through_id) VALUES (#{@owner.id}, #{one_of_many_id})")
            join_id = @shard_klass.connection.execute("SELECT last_insert_rowid()").first[0]
            @dependent_one_of_many = @sharded_dependent_has_many_through_klass.find(one_of_many_id)
          end

          it 'destroys the join on the shard' do
            lambda {@dependent_one_of_many.destroy}.should change(@sharded_dependent_join_klass, :count).by(-1)
          end
        end
      end

      context 'using a :has_and_belongs_to_many reflection' do
        before(:each) do
          @sharded_habtm_klass = Dynashard.sharded_model_class(@shard_klass, ShardedHabtm)
          @shard_klass.connection.execute("INSERT INTO sharded_habtms (name) VALUES ('#{Factory.next :name}')")
          habtm_id = @shard_klass.connection.execute("SELECT last_insert_rowid()").first[0]
          @shard_klass.connection.execute("INSERT INTO sharded_habtms_sharding_owners (sharding_owner_id, sharded_habtm_id) VALUES (#{@owner.id}, #{habtm_id})")
          @habtm = @sharded_habtm_klass.find(habtm_id)
          @join_counter = SqlCounter.new(@shard_klass.connection, 'SELECT COUNT(*) FROM sharded_habtms_sharding_owners')
        end

        it 'reads from the shard' do
          @owner.sharded_habtms.should include(@habtm)
        end

        it 'destroys the model from the shard' do
          lambda {@habtm.destroy}.should change(@sharded_habtm_klass, :count).by(-1)
        end

        # Rails seems to always use the ActiveRecord::Base connection
        # for habtm join tables
        xit 'destroys the join on the shard' do
          lambda {@habtm.destroy}.should change(@join_counter, :count).by(-1)
        end

        it 'creates_other on the shard' do
          lambda do
            @owner.sharded_habtms.create(:name => Factory.next(:name))
          end.should change(@sharded_habtm_klass, :count).by(1)
        end

        # Rails seems to always use the ActiveRecord::Base connection
        # for habtm join tables
        xit 'creates joins on the shard' do
          lambda do
            @owner.sharded_habtms.create(:name => Factory.next(:name))
          end.should change(@join_counter, :count).by(1)
        end

        it 'saves built associations on the shard' do
          new_habtm = @owner.sharded_habtms.build(:name => Factory.next(:name))
          lambda {@owner.save}.should change(@sharded_habtm_klass, :count).by(1)
        end

        # Rails seems to always use the ActiveRecord::Base connection
        # for habtm join tables
        xit 'saves built association joins on the shard' do
          new_habtm = @owner.sharded_habtms.build(:name => Factory.next(:name))
          lambda {@owner.save}.should change(@join_counter, :count).by(1)
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
