# Dynashard - Dynamic sharding for ActiveRecord

This package provides database sharding functionality for ActiveRecord models.

Sharding is disabled by default and is enabled with `Dynashard.enable`.  This allows
sharding behavior to be enabled globally or only for specific environments; for example,
production environments could be sharded while development environments could
use a single database.

Models may be configured to determine the appropriate shard (database connection) to
use based on context defined prior to performing queries.  Different
models may shard using different contexts.

    class Widget < ActiveRecord::Base
      shard :by => :user
    end

    class Doohickie < ActiveRecord::Base
      shard :by => :vhost
    end
  
    class WidgetController < ApplicationController
      around_filter :set_shard_context
  
      def index
        # Widgets will be loaded using the connection for the current user's shard
        @widgets = Widget.find(:all)

        # Doohickies will be loaded using the connection for the vhost's shard
        @doohickies = Doohickie.find(:all)
      end
  
      private
  
        def set_shard_context
          Dynashard.with_context(:user => current_user.shard, :vhost => request.env['HTTP_HOST']) do
            yield
          end
        end
    end

Sharded models are returned as objects of a shard-specific subclass.

    > new_widget = Dynashard.with_context(:user => 'shard1') {Widget.new(:name => 'New widget')}
    => <#Dynashard::Shard0::Widget id: nil, name: "New widget">

    > created_widget = Dynashard.with_context(:user => 'shard2') {Widget.create(:name => 'Created widget')}
    => <#Dynashard::Shard1::Widget id: 1, name: "Created widget">

    > found_widget = Dynashard.with_context(:user => 'shard3') {Widget.find(:first)}
    => <#Dynashard::Shard2::Widget id: 4, name: "Found widget">

    > found_widgets = Dynashard.with_context(:user => 'shard3') {Widget.find(:all)}
    => [<#Dynashard::Shard2::Widget id: 4, name: "Found widget">, <#Dynashard::Shard2::Widget id: 5, name: "Other found widget">]

  New objects are saved on the shard with the context that was active
  when the object was initialized.

    > new_widget.save
    => <#Dynashard::Shard0::Widget id: 1, name: "New widget">  # saved on 'shard1'

  Created and found objects are updated on the shard with the context
  that was active when they were created or found.

    > created_widget.update_attribute(:name, 'New name')
    => true  # updated on 'shard2'

    > found_widget.update_attributes(:name => 'Updated name')
    => true  # updated on 'shard3'

Shard context values may be a valid argument to establish_connection()
such as a string reference to a configuration from config/database.yml
or a hash with database connection parameters.  Values may also be an
object that responds to :call and returns a valid argument to
establish_connection().

  Load widgets from a shard defined in database.yml

    $ cat config/database.yml

    development:
      database: db/development.sqlite3
      <<: *defaults

    shard1:
      database: db/shard1.sqlite3
      <<: *defaults

    shard2:
      database: db/shard2.sqlite3
      <<: *defaults

    > @widgets = Dynashard.with_context(:user => 'shard1') { Widget.find(:all) }
    => [#<Dynashard::Shard0::Widget id:1>, #<Dynashard::Shard0::Widget id:2>]

  Load widgets from a shard using a hash of connection params

    > conn = {:adapter => 'sqlite3', :database => 'db/shard3.sqlite3'}
    > @widgets = Dynashard.with_context(:user => conn) { Widget.find(:all) }
    => [#<Dynashard::Shard2::Widget id:1>, #<Dynashard::Shard2::Widget id:2>]

  Create a widget using a method to determine the shard

    widget_shard = lambda do
      # Store widgets by month/day
      {:adapter => 'sqlite3', :database => "db/dayslice#{Time.now.strftime("%m%d")}"}
    end

    > Time.now
    => Mon Jan 31 17:37:23 -0800 2011

    > widget_shard.call
    => {:database=>"db/dayslice0131", :adapter=>"sqlite3"}

    > new_widget = Dynashard.with_context(:user => widget_shard) do
        Widget.create(:name => 'The newest of the widgets')
      end
    => <#Dynashard::Shard4::Widget id:3>

  Use a Rails initializer for one-time configuration of shard context

    $ cat config/initializers/dynashard.rb

    # Put user-sharded data on the smallest shard
    Dynashard.shard_context[:user] = lambda do
      Shard.order(:size).find(:first).dsn
    end

    > new_widget = Widget.create(:name => 'Put this on the smallest shard')
    => <#Dynashard::Shard5::Widget id:4>

  Use with_context to override an earlier context setting

    > Dynashard.shard_context[:user] = 'shard1'
    > new_widget = Widget.create(:name => 'Put this on shard1')
    => <#Dynashard::Shard0::Widget id:5>
    > new_widget = Dynashard.with_context(:user => 'shard2') do
        Widget.create(:name => 'Put this on shard2')
      do
    > <#Dynashard::Shard1::Widget id:6>

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

  Load a Company using the default ActiveRecord connection.

    > c = Company.find(:first)
    => #<Company id:1>

  Load Customers using the connection for the Company's shard.
  Associated models are returns as shard-specific subclasses of the
  association class.

    > c.customers
    => [#<Dynashard::Shard0::Customer id: 1>, #<Dynashard::Shard0::Customer id: 2>]

  Save new associations on the Company's shard.

    > c.customers.create(:name => 'Always right')
    => #<Dynashard::Shard0::Customer id: 3>

## TODO: add gotcha section, eg:

 - many-to-many associations can only be used across shards in one
   direction, where the association target and the join table exist
   on the same database connection (else joins don't work.)
 - uniqueness validations should be scoped by whatever is sharding
 - ways to shoot yourself in the foot with non-sharding association
   owners of sharded models
 - investigate proxy extend for association proxy
# Important change
