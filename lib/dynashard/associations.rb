module Dynashard
  module ProxyExtensions
    def self.included(base)
      base.alias_method_chain :initialize, :dynashard
    end

    # Initialize an association proxy.  If the proxy owner class is configured to
    # shard its associations and the reflection klass is sharded, use a custom
    # reflection with a sharded class.
    def initialize_with_dynashard(owner, reflection)
      if owner.class.shards_associated? && reflection.klass.sharding_enabled?
        reflection = Dynashard.reflection_for(owner, reflection)
      end
      initialize_without_dynashard(owner, reflection)
    end
  end
end

ActiveRecord::Associations::AssociationProxy.send(:include, Dynashard::ProxyExtensions)
