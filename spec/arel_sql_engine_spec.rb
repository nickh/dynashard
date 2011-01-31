require 'spec_helper'

describe 'Dynashard::ArelEngineExtensions' do
  before(:each) do
    @mock_record = mock()
    @engine = Arel::Sql::Engine.new(@mock_record)
  end

  describe '#connection_with_dynashard' do
    context 'with a sharding association owner' do
      it "returns the generated model subclass connection" do
        @mock_record.should_receive(:dynashard_klass).once.and_return(mock(:connection => :subclass_connection))
        @engine.should_receive(:connection_without_dynashard).never
        @engine.connection.should == :subclass_connection
      end
    end

    context 'with a sharding model' do
      before(:each) do
        @mock_record.should_receive(:sharding_enabled?).and_return(true)
        @mock_record.should_receive(:dynashard_context).at_least(:once).and_return(:dynashard_context)
      end

      context 'and no defined sharding context' do
        it 'raises an exception' do
          Dynashard.shard_context[:dynashard_context] = nil
          lambda do
            @engine.connection
          end.should raise_error
        end
      end
    
      context 'and a defined sharding context' do
        it 'returns the generated shard class connection' do
          Dynashard.should_receive(:class_for).with(:shard_spec).and_return(mock(:connection => :shard_connection))
          Dynashard.shard_context[:dynashard_context] = :shard_spec
          @engine.should_receive(:connection_without_dynashard).never
          @engine.connection.should == :shard_connection
        end
      end
    end

    context 'with a non-sharding model' do
      it 'returns the default connection' do
        @mock_record.should_receive(:sharding_enabled?).and_return(false)
        @engine.should_receive(:connection_without_dynashard).and_return(:model_connection)
        @engine.connection.should == :model_connection
      end
    end
  end
end
