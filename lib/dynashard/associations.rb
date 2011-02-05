module Dynashard
  module ProxyExtensions
    def self.included(base)
      base.alias_method_chain :initialize, :dynashard
    end

    # Initialize an association proxy.  If the proxy target needs to be sharded,
    # swap in a reflection with a sharded "klass" to ensure that the shard
    # connection is always used to manage records in the target model.
    def initialize_with_dynashard(owner, reflection)
      if needs_sharded_reflection?(owner, reflection)
        reflection = Dynashard.reflection_for(owner, reflection)
        if reflection.through_reflection != false && reflection.through_reflection.klass.sharding_enabled?
          reflection.instance_variable_set('@through_reflection', Dynashard.reflection_for(owner, reflection.through_reflection))
        end
      end
      initialize_without_dynashard(owner, reflection)
    end

    private

      # The reflection needs to use a sharded model class in these situations:
      # - the proxy owner shards associations, and the proxy target has sharding enabled
      # - the proxy owner is a dynashard-generated model class,
      #   the reflection class is configured to shard,
      #   the proxy owner superclass and reflection klass use the same shard context
      def needs_sharded_reflection?(owner, reflection)
        (owner.class.shards_associated? && reflection.klass.sharding_enabled?) ||
        (owner.class.dynashard_model? && reflection.klass.sharding_enabled? && owner.class.superclass.dynashard_context == reflection.klass.dynashard_context)
      end
  end
end

ActiveRecord::Associations::AssociationProxy.send(:include, Dynashard::ProxyExtensions)
