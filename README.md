# ActiveRecordProxyAdapters

[![Run Test Suite](https://github.com/Nasdaq/active_record_proxy_adapters/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/Nasdaq/active_record_proxy_adapters/actions/workflows/test.yml)

A set of ActiveRecord adapters that leverage Rails native multiple database setup to allow automatic connection switching from _one_ primary pool to _one_ replica pool at the database statement level.

## Why do I need this?

Maybe you don't. Rails already provides, since version 6.0, a [Rack middleware](https://guides.rubyonrails.org/active_record_multiple_databases.html#activating-automatic-role-switching) that switches between primary and replica automatically based on the HTTP request (`GET` and `HEAD` requests go the primary, everything else goes to the replica).

The caveat is: you are not allowed do any writes in any `GET` or `HEAD` requests (including controller callbacks).
Which means, for example, your `devise` callbacks that save user metadata will now crash.
So will your `ahoy-matey` callbacks.

You will then start wrapping those callbacks in `ApplicationRecord.connected_to(role :reading) {}` blocks as a workaround and, many months later, you have dozens of those (we had nearly 40 when we decided to build this gem).

By the way, that middleware only works at HTTP request layer (well, duh! it's a Rack middleware).
So not good for background jobs, cron jobs or anything that happens outside the scope of an HTTP request. And, if your application needs a replica at this point, for sure you would benefit from automatic connection switching in background jobs too, wouldn't you?

This gem is heavily inspired by [Makara](https://github.com/instacart/makara), a fantastic gem built by the Instacart folks, which is [no longer maintained](https://github.com/instacart/makara/issues/393), but we took a slightly different, slimmer approach. We don't support load balancing replicas, and that is by design. We believe that should be done outside the scope of the application (using tools like `Pgpool-II`, `pgcat` or RDS Proxy).

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add 'active_record_proxy_adapters'

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install active_record_proxy_adapters

## Usage

### On Rails

In `config/database.yml`, use `{your_database_adapter}_proxy` as the adapter for the `primary` database, and keep `{your_database_adapter}` for the replica database.

Currently supported adapters:

- `postgresql`
- `mysql2`
- `trilogy`
- `sqlite3`


#### PostgreSQL
```yaml
# config/database.yml
development:
  primary:
    adapter: postgresql_proxy
    # your primary credentials here

  primary_replica:
    adapter: postgresql
    replica: true
    # your replica credentials here
```

#### MySQL
```yaml
# config/database.yml
development:
  primary:
    adapter: mysql2_proxy
    # your primary credentials here

  primary_replica:
    adapter: mysql2
    replica: true
    # your replica credentials here
```

#### Trilogy
```yaml
# config/database.yml
development:
  primary:
    adapter: trilogy_proxy
    # your primary credentials here

  primary_replica:
    adapter: trilogy
    replica: true
    # your replica credentials here
```

#### SQLite
```yaml
# config/database.yml
development:
  primary:
    adapter: sqlite3_proxy
    # your primary credentials here

  primary_replica:
    adapter: sqlite3
    replica: true
    # your replica credentials here
```

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :primary, reading: :primary_replica }
end
```

### Off Rails

```ruby
# In your application setup
require "active_record_proxy_adapters"
require "active_record_proxy_adapters/connection_handling"

# in your base model
class ApplicationRecord << ActiveRecord::Base
    establish_connection(
        {
            adapter: 'postgresql_proxy', # or any of the following: mysql2_proxy, trilogy_proxy, sqlite3_proxy
            # your primary credentials here
        },
        role: :writing
    )

    establish_connection(
        {
            adapter: 'postgresql',  # or any of the following: mysql2, trilogy, sqlite3
            # your replica credentials here
        },
        role: :reading
    )
end
```

## Configuration

The gem comes preconfigured out of the box. However, if default configuration does not suit your needs, you can modify it by using a `.configure` block:

```ruby
# config/initializers/active_record_proxy_adapters.rb
ActiveRecordProxyAdapters.configure do |config|
  # How long proxy should reroute all read requests to primary after a write
  config.proxy_delay = 5.seconds # defaults to 2.seconds

  # How long proxy should wait for replica to connect.
  config.checkout_timeout = 5.seconds # defaults to 2.seconds
end
```

## Logging

```ruby
# config/initializers/active_record_proxy_adapters.rb
require "active_record_proxy_adapters/log_subscriber"

ActiveRecordProxyAdapters.configure do |config|
  config.log_subscriber_primary_prefix = "My primary tag" # defaults to "#{adapter_name} Primary", i.e "PostgreSQL Primary"
  config.log_subscriber_replica_prefix = "My replica tag" # defaults to "#{adapter_name} Replica", i.e "PostgreSQL Replica"
end

# You may want to remove duplicate logs
ActiveRecord::LogSubscriber.detach_from :active_record
```

### Example:

```ruby
irb(main):001> User.count ; User.create(name: 'John Doe', email: 'john.doe@example.com') ; 3.times { User.count ; sleep(1) }
```
yields

```
D, [2024-12-24T17:18:49.151235 #328] DEBUG -- :   [My replica tag] User Count (0.5ms)  SELECT COUNT(*) FROM "users"
D, [2024-12-24T17:18:49.156633 #328] DEBUG -- :   [My primary tag] TRANSACTION (0.1ms)  BEGIN
D, [2024-12-24T17:18:49.157323 #328] DEBUG -- :   [My primary tag] User Create (0.4ms)  INSERT INTO "users" ("name", "email", "created_at", "updated_at") VALUES ($1, $2, $3, $4) RETURNING "id"  [["name", "John Doe"], ["email", "john.doe@example.com"], ["created_at", "2024-12-24 17:18:49.156063"], ["updated_at", "2024-12-24 17:18:49.156063"]]
D, [2024-12-24T17:18:49.158305 #328] DEBUG -- :   [My primary tag] TRANSACTION (0.7ms)  COMMIT
D, [2024-12-24T17:18:49.159079 #328] DEBUG -- :   [My primary tag] User Count (0.3ms)  SELECT COUNT(*) FROM "users"
D, [2024-12-24T17:18:50.166105 #328] DEBUG -- :   [My primary tag] User Count (1.9ms)  SELECT COUNT(*) FROM "users"
D, [2024-12-24T17:18:51.169911 #328] DEBUG -- :   [My replica tag] User Count (0.9ms)  SELECT COUNT(*) FROM "users"
=> 3
```

## How it works

The proxy will analyze each SQL string, using pattern matching, to decide the appropriate connection for it (i.e. if it should go to the primary or replica).

- All queries inside a transaction go to the primary
- All `SET` queries go to all connections
- All `INSERT`, `UPDATE` and `DELETE` queries go to the primary
- All `SELECT FOR UPDATE` queries go to the primary
- All `lock` queries (e.g `get_lock`) go the primary
- All sequence methods (e.g `nextval`) go the primary
- Everything else goes to the replica

### TL;DR

All `SELECT` queries go to the _replica_, everything else goes to _primary_.

## Stickiness context

Similar to Rails' built-in [automatic role switching](https://guides.rubyonrails.org/active_record_multiple_databases.html#activating-automatic-role-switching) Rack middleware, the proxy guarantes read-your-own-writes consistency by keeping a contextual timestamp for each Adapter Instance (a.k.a what you get when you call `Model.connection`).

Until `config.proxy_delay` time has been reached, all subsequent read requests _only for that connection_ will be rerouted to the primary. Once that has been reached, all following read requests will go the replica.

Although the gem comes configured out of the box with `config.proxy_delay = 2.seconds`, it is your responsibility to find the proper number to use here, as that is very particular to each application and may be affected by many different factors (i.e. hardware, workload, availability, fault-tolerance, etc.). **Do not use this gem** if you don't have any replication delay metrics avaiable in your production APM. And make sure you have the proper alerts setup in case there's a spike in replication delay.

One strategy you can use to quickly disable the proxy is set your adapter using an environment variable:

```yaml
# config/database.yml
production:
  primary:
    adapter: <%= ENV.fetch("PRIMARY_DATABASE_ADAPTER", "postgresql") %>
  primary_replica:
    adapter: postgresql
    replica: true
```
Then set `PRIMARY_DATABASE_ADAPTER=postgresql_proxy` to enable the proxy.
That way you can redeploy your application disabling the proxy completely, without any code change.

### Sticking to a database manually

The proxy respects ActiveRecord's `#connected_to_stack` and will use it if present.
You can use that to force connection to the primary or replica and bypass the proxy entirely.

```ruby
User.create(name: 'John Doe', email: 'john.doe@example.com')
last_user = User.last # This would normally go to the primary to adhere to read-your-own-writes consistency
last_user = ApplicationRecord.connected_to(role: :reading) { User.last } # but I can override it with this block
```

This is useful when picking up a background job that could be impacted by replication delay.

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :primary, reading: :primary_replica }
end

# app/models/user.rb
class User < ApplicationRecord
  validates :name, :email, presence: true

  after_commit :say_hello, on: :create

  private

  def say_hello
    SayHelloJob.perform_later(id) # new row may not be replicated yet
  end
end

# app/jobs/say_hello_job.rb
class SayHelloJob < ApplicationJob
  def perform(user_id)
    # so we manually reroute it to the primary
    user = ApplicationRecord.connected_to(role: :writing) { User.find(user_id) }

    UserMailer.welcome(user).deliver_now
  end
end
```

## Caching Configuration

ActiveRecordProxyAdapters supports caching of SQL pattern matching results to improve performance for frequently executed queries.

### Enabling Caching

By default, caching is disabled (using `NullStore`). To enable caching:

```ruby
ActiveRecordProxyAdapters.configure do |config|
  # Configure the cache store
  config.cache do |cache|
    # Use a specific cache implementation
    # Notice that if using a Memcached or a Redis store, the network latency may outweigh the benefits you would get from caching the pattern matching
    cache.store = ActiveSupport::Cache::MemoryStore.new(size: 64.megabytes)

    # Optional: Customize the cache key prefix (default: "arpa_")
    cache.key_prefix = "custom_prefix_"

    # Optional: Customize the cache key generation (default: SHA2 hexdigest)
    cache.key_builder = ->(sql) { "sql_#{Digest::MD5.hexdigest(sql)}" }
  end
end
```

### How Caching Works
The caching system stores the results of SQL pattern matching operations to determine whether a query should be routed to a primary or replica database. This improves performance by avoiding repeated pattern matching on identical SQL strings.

- Cache keys are generated using the configured `key_builder` (SHA2 digest by default).
- All keys are prefixed with the configured `key_prefix` ("arpa_" by default).
- Cache misses are instrumented with the `active_record_proxy_adapters.cache_miss` notification. They can be monitored by subscribing to that topic:
  ```ruby
  ActiveSupport::Notifications.subscribe("active_record_proxy_adapters.cache_miss") do |event|
    cache_key, sql = event[:payload].values_at(:cache_key, :sql)

    logger.info("Cache miss for SQL: #{sql.inspect} with cache key: #{cache_key.inspec}")
  end
  ```

### Busting the cache

If you ever need to manually clear the cached SQL patterns:

```ruby
# This will clear all cached entries with the configured prefix
ActiveRecordProxyAdapters.bust_query_cache
```

### Performance Considerations
For applications with a high volume of repetitive queries, enabling caching can significantly reduce CPU overhead from SQL parsing. However, this comes with the tradeoff of increased memory usage in your cache store.

For optimal results:
- Consider enabling prepared statements as that will increase cache hit rate, and decrease cache growth rate
  ```ruby
  irb(main):001> (1..10).each { |i| User.where(id: i).exists? }
  ```
  _Without_ Prepared statements yields
  ```
  Cache miss for SQL: "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"id\" = 1 LIMIT 1" with cache key: "arpa_9fa3972e45b27985eef6bfb4aa6269c12d43363c60e7aa67fb290ec317503710"
  Cache miss for SQL: "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"id\" = 2 LIMIT 1" with cache key: "arpa_0e51756270138442ad26087dffcfb53c21df4a430961f1ca3b4270183f4b066d"
  Cache miss for SQL: "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"id\" = 3 LIMIT 1" with cache key: "arpa_db5b8c323ee2c284ba96adc6e20b7ea1373ca07fa9b09969f5207d467bd895b6"
  Cache miss for SQL: "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"id\" = 4 LIMIT 1" with cache key: "arpa_129459a1ba342cad3dbd4458cd8eacda4ed641a94a5d1e6cc23604495e44b565"
  Cache miss for SQL: "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"id\" = 5 LIMIT 1" with cache key: "arpa_9817a74a6f162ea110ed14cef79e95aa78830ff19266cdce75668e0c9c5ccef7"
  Cache miss for SQL: "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"id\" = 6 LIMIT 1" with cache key: "arpa_610e37a117abc81ec1afebafa0f36b35547f57879536ca7535475075ea08d8ac"
  Cache miss for SQL: "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"id\" = 7 LIMIT 1" with cache key: "arpa_79e172d168c59c4e5befbe954861ff9076000f955719dd3cca1423b68fb5f319"
  Cache miss for SQL: "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"id\" = 8 LIMIT 1" with cache key: "arpa_fb29367bdae3e2a48d1fa63cca00fd611c0b6dc84c9f5fd985b9222d49f1f7d9"
  Cache miss for SQL: "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"id\" = 9 LIMIT 1" with cache key: "arpa_e6e9a73cf9066077893b21dde038e5a616bf25731aeb5a4a9cdb41b7d84d1ece"
  Cache miss for SQL: "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"id\" = 10 LIMIT 1" with cache key: "arpa_8c94cdae65b6d529364d6ae8cf68f0e827566d471d2bd1107d6bdca29345759e"
  ```

  _With_ prepared statments yields
  ```
  Cache miss for SQL: "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"id\" = $1 LIMIT $2" with cache key: "arpa_3c2ef2bb9a5f370adf63eac3bc9994c054554798d31d247818049c8c21cb68be"
  ```
- Use a cache store with an appropriate size limit, and low latency (Memory Store has lower latency than Memcached or Redis)
- Monitor cache hit/miss rates using the instrumentation events
- Consider occasionally busting the cache during low-traffic periods to prevent stale entries, or setting a reasonable expiry window for cached values

### Thread safety

Since Rails already leases exactly one connection per thread from the pool and the adapter operates on that premise, it is safe to use it in multi-threaded servers such as Puma.

As long as you're not writing thread unsafe code that handles connections from the pool directly, or you don't have any other gem depenencies that write thread unsafe pool operations, you're all set.

Multi-threaded queries example:
```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :primary, reading: :primary_replica }
end

# app/models/portal.rb
class Portal < ApplicationRecord
  validates :name, uniqueness: true
end

# in rails console -e test
ActiveRecord::Base.logger.formatter = proc do |_severity, _time, _progname, msg|
  "[#{Time.current.iso8601} THREAD #{Thread.current[:name]}] #{msg}\n"
end

ActiveRecordProxyAdapters.configure do |config|
  config.proxy_delay = 2.seconds
end

def read_your_own_writes
  proc do
    Portal.all.count # should go to the replica
    Portal.create(name: 'Read your own write')

    5.times do
      Portal.all.count # first one goes the primary, last 4 should go to the replica
      sleep(3)
    end
  end
end

def use_replica
  proc do
    5.times do
      Portal.all.count # should always go the replica
      sleep(1.5)
    end
  end
end

def executor
  Rails.application.executor
end

def test_multithread_queries
  ActiveRecordProxyAdapters.configure do |config|
    config.proxy_delay = 2.seconds
    config.checkout_timeout = 2.seconds
  end

  t1 = Thread.new do
    Thread.current[:name] = "USE REPLICA"
    executor.wrap { ActiveRecord::Base.uncached { use_replica.call } }
  end

  t2 = Thread.new do
    Thread.current[:name] = "READ YOUR OWN WRITES"
    executor.wrap { ActiveRecord::Base.uncached { read_your_own_writes.call } }
  end

  [t1, t2].each(&:join)
end
```

Yields:
```bash
irb(main):051:0> test_multithread_queries
[2024-12-24T13:52:40-05:00 THREAD USE REPLICA]   [PostgreSQL Replica] Portal Count (1.4ms)  SELECT COUNT(*) FROM "portals"
[2024-12-24T13:52:40-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQL Replica] Portal Count (0.4ms)  SELECT COUNT(*) FROM "portals"
[2024-12-24T13:52:40-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQLProxy Primary] TRANSACTION (0.5ms)  BEGIN
[2024-12-24T13:52:40-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQLProxy Primary] Portal Exists? (0.4ms)  SELECT 1 AS one FROM "portals" WHERE "portals"."name" = $1 LIMIT $2  [["name", "Read your own write"], ["LIMIT", 1]]
[2024-12-24T13:52:40-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQLProxy Primary] Portal Create (0.8ms)  INSERT INTO "portals" ("name", "created_at", "updated_at") VALUES ($1, $2, $3) RETURNING "id"  [["name", "Read your own write"], ["created_at", "2024-12-24 18:52:40.428383"], ["updated_at", "2024-12-24 18:52:40.428383"]]
[2024-12-24T13:52:40-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQLProxy Primary] TRANSACTION (0.7ms)  COMMIT
[2024-12-24T13:52:40-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQLProxy Primary] Portal Count (0.6ms)  SELECT COUNT(*) FROM "portals"
[2024-12-24T13:52:41-05:00 THREAD USE REPLICA]   [PostgreSQL Replica] Portal Count (4.4ms)  SELECT COUNT(*) FROM "portals"
[2024-12-24T13:52:43-05:00 THREAD USE REPLICA]   [PostgreSQL Replica] Portal Count (3.3ms)  SELECT COUNT(*) FROM "portals"
[2024-12-24T13:52:43-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQL Replica] Portal Count (2.8ms)  SELECT COUNT(*) FROM "portals"
[2024-12-24T13:52:44-05:00 THREAD USE REPLICA]   [PostgreSQL Replica] Portal Count (18.0ms)  SELECT COUNT(*) FROM "portals"
[2024-12-24T13:52:46-05:00 THREAD USE REPLICA]   [PostgreSQL Replica] Portal Count (0.9ms)  SELECT COUNT(*) FROM "portals"
[2024-12-24T13:52:46-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQL Replica] Portal Count (2.3ms)  SELECT COUNT(*) FROM "portals"
[2024-12-24T13:52:49-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQL Replica] Portal Count (7.2ms)  SELECT COUNT(*) FROM "portals"
[2024-12-24T13:52:52-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQL Replica] Portal Count (3.7ms)  SELECT COUNT(*) FROM "portals"
=> [#<Thread:0x00007fffdd6c9348 (irb):38 dead>, #<Thread:0x00007fffdd6c9230 (irb):43 dead>]
```

## Building your own proxy

These instructions assume an active record adapter `ActiveRecord::ConnectionAdapters::FoobarAdapter` already exists and is properly loaded in your environment.

To create a proxy adapter for an existing database `FoobarAdapter`, follow these steps under the lib folder of your rails application source code:

1. **Create database tasks for your proxy adapter** to allow Rails tasks like `db:create` and `db:migrate` to work:

   ```ruby
   # lib/active_record/tasks/foobar_proxy_database_tasks.rb

   require "active_record_proxy_adapters/database_tasks"

   module ActiveRecord
     module Tasks
       class FoobarProxyDatabaseTasks < FoobarDatabaseTasks
         include ActiveRecordProxyAdapters::DatabaseTasks
       end
     end
   end

   ActiveRecord::Tasks::DatabaseTasks.register_task(
     /foobar_proxy/,
     "ActiveRecord::Tasks::FoobarProxyDatabaseTasks"
   )
   ```

2. **Create the proxy implementation class** that will handle the routing logic:

   ```ruby
   # lib/active_record_proxy_adapters/foobar_proxy.rb

   require "active_record_proxy_adapters/primary_replica_proxy"

   module ActiveRecordProxyAdapters
     class FoobarProxy < PrimaryReplicaProxy
       # Override or hijack extra methods here if you need custom behavior
       # For most adapters, the default behavior works fine
     end
   end
   ```

3. **Create the proxy adapter class** that inherits from the underlying adapter, including the `Hijackable` concern. You need to require the database tasks source, the original adapter source, and the proxy source:

   ```ruby
   # lib/active_record/connection_adapters/foobar_proxy_adapter.rb

   require "active_record/tasks/foobar_proxy_database_tasks"
   require "active_record/connection_adapters/foobar_adapter"
   require "active_record_proxy_adapters/active_record_context"
   require "active_record_proxy_adapters/hijackable"
   require "active_record_proxy_adapters/foobar_proxy"

   module ActiveRecord
     module ConnectionAdapters
       class FoobarProxyAdapter < FoobarAdapter
         include ActiveRecordProxyAdapters::Hijackable

         ADAPTER_NAME = "FoobarProxy" # This is only an ActiveRecord convention and is not required to work

         delegate_to_proxy(*ActiveRecordProxyAdapters::ActiveRecordContext.hijackable_methods)

         def initialize(...)
           @proxy = ActiveRecordProxyAdapters::FoobarProxy.new(self)

           super
         end

         private

         attr_reader :proxy
       end
     end
   end

   # This is only required for Rails 7.2 or greater.
   if ActiveRecordProxyAdapters::ActiveRecordContext.active_record_v7_2_or_greater?
     ActiveRecord::ConnectionAdapters.register(
       "foobar_proxy",
       "ActiveRecord::ConnectionAdapters::FoobarProxyAdapter",
       "active_record/connection_adapters/foobar_proxy_adapter"
     )
   end

   ActiveSupport.run_load_hooks(:active_record_foobarproxyadapter,
                                ActiveRecord::ConnectionAdapters::FoobarProxyAdapter)
   ```

4. **Create connection handling module** for ActiveRecord integration:

   ```ruby
   # lib/active_record_proxy_adapters/connection_handling/foobar.rb

   begin
     require "active_record/connection_adapters/foobar_proxy_adapter"
   rescue LoadError
     # foobar not available
     return
   end

   # This is only required for Rails 7.0 or earlier.
   module ActiveRecordProxyAdapters
     module Foobar
       module ConnectionHandling
         def foobar_proxy_adapter_class
           ActiveRecord::ConnectionAdapters::FoobarProxyAdapter
         end

         def foobar_proxy_connection(config)
            # copy and paste the contents of the original method foobar_connection here.
            # If the contents contain a hardcoded FooBarAdapter.new instance,
            # replace it with foobar_proxy_adapter_class.new
         end
       end
     end
   end

   ActiveSupport.on_load(:active_record) do
     ActiveRecord::Base.extend(ActiveRecordProxyAdapters::Foobar::ConnectionHandling)
   end
   ```

5. **In your initializer, load the custom adapter** when the parent adapter is fully loaded:

   ```ruby
   # config/initializers/active_record_proxy_adapters.rb

   # The parent adapter should have a load hook already. If not, you might need to monkey patch it.
   ActiveSupport.on_load(:active_record_foobaradapter) do
     require "active_record_proxy_adapters/connection_handling/foobar"
   end
   ```

6. **Add a custom Zeitwerk inflection rule** if your adapter file paths do not follow Rails conventions. You can skip this if it does:

   ```ruby
   # config/initializers/active_record_proxy_adapters.rb

   Rails.autoloaders.each do |autoloader|
     autoloader.inflector.inflect(
       "foobar_proxy_adapter" => "FoobarProxyAdapter"
     )
   end
   ```

7. **Configure your database.yml** to use your new adapter:

   ```yaml
   development:
     primary:
       adapter: foobar_proxy
       # primary database configuration

     primary_replica:
       adapter: foobar
       replica: true
       # replica database configuration
   ```

8. **Set up your model to use both connections**:

   ```ruby
   class ApplicationRecord < ActiveRecord::Base
     self.abstract_class = true
     connects_to database: { writing: :primary, reading: :primary_replica }
   end
   ```

For testing your adapter, follow the examples in the test suite by creating spec files that match the pattern used for the other adapters.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nasdaq/active_record_proxy_adapters. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/nasdaq/active_record_proxy_adapters/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActiveRecordProxyAdapters project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/nasdaq/active_record_proxy_adapters/blob/main/CODE_OF_CONDUCT.md).
