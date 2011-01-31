= Dynashard - Dynamic sharding for ActiveRecord

This package provides database sharding functionality for ActiveRecord models.

Sharding is disabled by default and is enabled with +Dynashard.enable+.  This allows
sharding behavior to be enabled globally or only for specific environments so for
example production environments could be sharded while development environments could
use a single database.

Models may be configured to determine the appropriate shard (database connection) to
use based on context defined prior to performing queries.

  class Widget < ActiveRecord::Base
    shard :by => :user
  end

  class WidgetController < ApplicationController
    around_filter :set_shard_context

    def index
      # Widgets will be loaded using the connection for the current user's shard
      @widgets = Widget.find(:all)
    end

    private

      def set_shard_context
        Dynashard.with_context(:user => current_user.shard) do
          yield
        end
      end
  end

Associated models may be configured to use different shards determined by the
association's owner.

  class Company < ActiveRecord::Base
    shard :associated, :using => :shard

    has_many :customers

    def shard
      # logic to find the company's shard
    end
  end

  class Customer < ActiveRecord::Base
    belongs_to :company
    shard :by => :company
  end

  > c = Company.find(:first)
  => #<Company id:1>

  Company is loaded using the default ActiveRecord connection.

  > c.customers
  => [#<Dynashard::Shard0::Customer id: 1>, #<Dynashard::Shard0::Customer id: 2>]

  Customers are loaded using the connection for the Company's shard.  Associated models
  are returned as shard-specific subclasses of the association class.

  > c.customers.create(:name => 'Always right')
  => #<Dynashard::Shard0::Customer id: 3>

  New associations are saved on the Company's shard.

TODO: add gotcha section, eg:
 - uniqueness validations should be scoped by whatever is sharding

