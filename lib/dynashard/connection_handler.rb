module Dynashard
  module ConnectionHandlerExtensions
    def self.included(base)
      base.alias_method_chain :retrieve_connection_pool, :dynashard
    end
    
    # Set an connection pool entry for the model class pointing at
    # the shard class's pool.
    # :nodoc:
    # This is required for places that examine the connection pool to
    # determine whether to use a given class's connection or a parent
    # class's connection (eg. ActiveRecord::Base.arel_engine)
    def dynashard_pool_alias(model_class, shard_class)
      @connection_pools[model_class] = @connection_pools[shard_class]
    end

    # Return a connection pool for the specified class.  If sharding
    # is enabled, the correct pool for the configured sharding context
    # will be used.
    #
    # :nodoc:
    # Reflection classes generated for an association proxy will
    # respond to :dynashard_klass and return a class with an
    # established connection to the correct shard.
    #
    # Sharded models will have a dynashard context defined, which
    # can be used as a key to the Dynashard.shard_context hash to
    # access the shard's connection specification.
    def retrieve_connection_pool_with_dynashard(klass)
      if klass.respond_to?(:dynashard_klass)
        retrieve_connection_pool_without_dynashard(klass.dynashard_klass)
      elsif klass.sharding_enabled?
        spec = Dynashard.shard_context[klass.dynashard_context]
        raise "Missing #{klass.dynashard_context} shard context" if spec.nil?
        spec = spec.call if spec.respond_to?(:call)
        shard_klass = Dynashard.class_for(spec)
        retrieve_connection_pool_without_dynashard(shard_klass)
      else
        retrieve_connection_pool_without_dynashard(klass)
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::ConnectionHandler.send(:include, Dynashard::ConnectionHandlerExtensions)
