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

    # Return a connection pool for the specified class.  If the class
    # is a Dynashard generated model subclass, return the connection
    # for its shard class.
    def retrieve_connection_pool_with_dynashard(klass)
      if klass.respond_to?(:dynashard_klass)
        retrieve_connection_pool_without_dynashard(klass.dynashard_klass)
      else
        retrieve_connection_pool_without_dynashard(klass)
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::ConnectionHandler.send(:include, Dynashard::ConnectionHandlerExtensions)
