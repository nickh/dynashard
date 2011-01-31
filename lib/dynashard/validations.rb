module Dynashard
  module ValidationExtensions
    def self.included(base)
      base.alias_method_chain :find_finder_class_for, :dynashard
    end
    
    # Return the class that should be used to find other instances of
    # the specified record's model class.  If the record is an instance
    # of a sharded model, it should be used; otherwise the default
    # behavior should be used.
    def find_finder_class_for_with_dynashard(record)
      if record.class.dynashard_model?
        record.class
      elsif record.class.sharding_enabled?
        record.class.dynashard_sharded_subclass
      else
        find_finder_class_for_without_dynashard(record)
      end
    end
  end
end

ActiveRecord::Validations::UniquenessValidator.send(:include, Dynashard::ValidationExtensions)
