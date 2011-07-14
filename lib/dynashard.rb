# = Dynashard - Dynamic sharding for ActiveRecord
#
# This package provides database sharding functionality for ActiveRecord models.
#
# Sharding is disabled by default and is enabled with +Dynashard.enable+.  This allows
# sharding behavior to be enabled globally or only for specific environments so for
# example production environments could be sharded while development environments could
# use a single database.
#
# Models may be configured to determine the appropriate shard (database connection) to
# use based on context defined prior to performing queries.
#
#   class Widget < ActiveRecord::Base
#     shard :by => :user
#   end
#
#   class WidgetController < ApplicationController
#     around_filter :set_shard_context
#
#     def index
#       # Widgets will be loaded using the connection for the current user's shard
#       @widgets = Widget.find(:all)
#     end
#
#     private
#
#       def set_shard_context
#         Dynashard.with_context(:user => current_user.shard) do
#           yield
#         end
#       end
#   end
#
# Associated models may be configured to use different shards determined by the
# association's owner.
#
#   class Company < ActiveRecord::Base
#     shard :associated, :using => :shard
#
#     has_many :customers
#
#     def shard
#       # logic to find the company's shard
#     end
#   end
#
#   class Customer < ActiveRecord::Base
#     belongs_to :company
#     shard :by => :company
#   end
#
#   > c = Company.find(:first)
#   => #<Company id:1>
#
#   Company is loaded using the default ActiveRecord connection.
#
#   > c.customers
#   => [#<Dynashard::Shard0::Customer id: 1>, #<Dynashard::Shard0::Customer id: 2>]
#
#   Customers are loaded using the connection for the Company's shard.  Associated models
#   are returned as shard-specific subclasses of the association class.
#
#   > c.customers.create(:name => 'Always right')
#   => #<Dynashard::Shard0::Customer id: 3>
#
#   New associations are saved on the Company's shard.
#
# TODO: add gotcha section, eg:
#  - uniqueness validations should be scoped by whatever is sharding

module Dynashard
  # Dynashard::ShardSpecification allows users to associate a name with generated
  # shard classes
  class Shard
    attr_reader :name, :spec

    def initialize(options={})
      @name = options[:name]
      @spec = options[:spec]
      raise ArgumentError.new('missing :spec') if @spec.nil?
    end
  end

  # Enable sharding for all models configured to do so
  def self.enable
    @enabled = true
  end

  # Disable sharding for all models configured to do so
  def self.disable
    @enabled = false
  end

  # Return true if sharding is globally enabled
  def self.enabled?
    @enabled == true
  end

  # Execute a block within a given sharding context
  def self.with_context(new_context, &block)
    orig_context = shard_context.dup
    shard_context.merge! new_context
    result = nil
    begin
      result = yield
    ensure
      shard_context.replace orig_context
    end
    result
  end

  # Return a threadsafe(?) current mapping of shard context to connection spec
  def self.shard_context
    Thread.current[:shard_context] ||= {}
  end

  # Return a class with an established connection to a database shard
  def self.class_for(spec)
    @class_cache ||= {}
    @class_cache[spec] ||= new_shard_class(spec)
    @class_cache[spec]
  end

  # Return a reflection with a sharded class
  def self.reflection_for(owner, reflection)
    reflection_copy = reflection.dup
    shard_klass = if owner.class.respond_to?(:dynashard_klass)
      owner.class.dynashard_klass
    else
      Dynashard.class_for(owner.send(owner.class.dynashard_association_using))
    end
    klass = sharded_model_class(shard_klass, reflection.klass)
    reflection_copy.instance_variable_set('@klass', klass)
    reflection_copy.instance_variable_set('@class_name', klass.name)

    reflection_copy
  end

  # Return a model subclass configured to use a specific shard
  def self.sharded_model_class(shard_klass, base_klass)
    class_name = "#{shard_klass.name}::#{base_klass.name}"
    unless shard_klass.constants.include?(base_klass.name.to_sym)
      class_eval <<EOE
        class #{class_name} < #{base_klass.name}
          @@dynashard_klass = #{shard_klass.name}

          def self.dynashard_model?()
            true
          end

          def self.dynashard_klass()
            @@dynashard_klass
          end

          def self.connection
            dynashard_klass.connection
          end

          def self.dynashard_context
            superclass.dynashard_context
          end
        end
EOE
      klass = class_name.constantize
      klass.connection_handler.dynashard_pool_alias(klass.name, shard_klass.name)
    end
    class_name.constantize
  end

  private

    def self.new_shard_class(spec)
      shard_number = @class_cache.size
      shard_id     = "Shard#{shard_number}"
      shard = if spec.is_a?(Dynashard::Shard)
                spec
              else
                Dynashard::Shard.new(:name => shard_id, :spec => spec)
              end
      unless const_defined?(shard_id)
        module_eval <<EOE
          class #{shard_id} < ActiveRecord::Base
            def self.shard
              @shard
            end

            def self.shard=(shard)
              @shard=shard
            end
          end
EOE
        module_eval("class #{shard_id} < ActiveRecord::Base ; end")
        klass = "Dynashard::#{shard_id}".constantize
        klass.shard = shard
        klass.establish_connection(shard.spec)
        ActiveRecord::Base.connection_handler.connection_pools[klass.name].spec.config[:shard] = shard.name
      end
      "Dynashard::#{shard_id}".constantize
    end
end

require 'dynashard/model'
require 'dynashard/associations'
require 'dynashard/connection_handler'
require 'dynashard/validations'
