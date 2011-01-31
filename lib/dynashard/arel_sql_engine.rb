module Dynashard
  module ArelEngineExtensions
    def self.included(base)
      base.alias_method_chain :connection, :dynashard
    end
    
    def connection_with_dynashard
      if @ar && @ar.respond_to?(:dynashard_klass)
        @ar.dynashard_klass.connection
      elsif @ar && @ar.sharding_enabled?
        spec = Dynashard.shard_context[@ar.dynashard_context]
        raise "Missing #{@ar.dynashard_context} shard context" if spec.nil?
        spec = spec.call if spec.respond_to?(:call)
        Dynashard.class_for(spec).connection
      else
        connection_without_dynashard
      end
    end
  end
end

Arel::Sql::Engine.send(:include, Dynashard::ArelEngineExtensions)
