require 'spec_helper'

describe 'Dynashard' do
  it 'can be enabled' do
    Dynashard.should respond_to(:enable)
    Dynashard.enable
    Dynashard.should be_enabled
  end

  it 'can be disabled' do
    Dynashard.should respond_to(:disable)
    Dynashard.disable
    Dynashard.should_not be_enabled
  end

  describe '#shard_context' do
    it 'is threadsafe' do
      Dynashard.shard_context[:test] = true
      t = Thread.new {Dynashard.shard_context[:test] = false}
      t.join
      Dynashard.shard_context[:test].should be_true
    end
  end

  describe '#class_for' do
    before(:each) do
      @shard_klass = Dynashard.class_for('shard1')
    end

    it 'returns a class' do
      @shard_klass.should be_a(Class)
    end

    it 'has an established connection' do
      ActiveRecord::Base.connection_handler.connection_pools.should have_key(@shard_klass.name)
    end

    it 'does not regenerate existing classes' do
      other_klass = Dynashard.class_for('shard1')
      other_klass.should == @shard_klass
    end

    # Ie. from config/database.yml
    it 'accepts a string reference to a configured database' do
      lambda do
        Dynashard.class_for('shard2')
      end.should_not raise_error
    end

    it 'accepts a hash with valid database connection parameters' do
      lambda do
        Dynashard.class_for({:adapter => 'sqlite3', :database => 'db/shard3.sqlite3'})
      end.should_not raise_error
    end
  end

  describe '#reflection_for' do
    before(:each) do
      @owner = Factory(:sharding_owner)
      @reflection = Dynashard.reflection_for(@owner, ShardingOwner.reflections[:sharded_has_one])
      @shard_klass = Dynashard.class_for(@owner.shard_dsn)
    end

    it 'returns a reflection' do
      @reflection.should be_kind_of(ActiveRecord::Reflection::MacroReflection)
    end

    it 'has a sharded class' do
      @reflection.klass.should respond_to(:dynashard_klass)
    end
  end

  describe '#sharded_model_class' do
    before(:each) do
      @owner = Factory(:sharding_owner)
      @reflection = Dynashard.reflection_for(@owner, ShardingOwner.reflections[:sharded_has_one])
      @shard_klass = Dynashard.class_for(@owner.shard_dsn)
    end

    it 'identifies as a sharded model' do
      @reflection.klass.should respond_to(:dynashard_model?)
      @reflection.klass.dynashard_model?.should be_true
    end

    it 'returns the shard class' do
      @reflection.klass.dynashard_klass.should == @shard_klass
    end

    it 'returns the shard class connection' do
      @reflection.klass.connection.should == @shard_klass.connection
    end

    it 'are not regenerated' do
      other_reflection = Dynashard.reflection_for(@owner, ShardingOwner.reflections[:sharded_has_one])
      other_reflection.klass.should == @reflection.klass
    end
  end

  describe '#with_context' do
    before(:each) do
      @test_context = {:foo => 'shard1'}
    end

    it 'sets the shard context for the given block' do
      Dynashard.with_context(@test_context) do
        Dynashard.shard_context[:foo].should == 'shard1'
      end
    end

    it 'resets the shard context' do
      Dynashard.with_context(@test_context) {}
      Dynashard.shard_context.should_not have_key(:foo)
    end

    it 'returns the block result' do
      Dynashard.with_context(@test_context) { 'foo' }.should == 'foo'
    end

    context 'when the block raises an exception' do
      it 'resets the shard context' do
        Dynashard.with_context(@test_context) { raise 'Aah!' } rescue nil
        Dynashard.shard_context.should_not have_key(:foo)
      end
    end
  end
end
