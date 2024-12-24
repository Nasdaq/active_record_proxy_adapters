# ActiveRecordProxyAdapters

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

In `config/database.yml`, use `postgresql_proxy` as the adapter for the `primary` database, and keep `postgresql` for the replica database.

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

ActiveSupport.on_load :active_record do
  require "active_record_proxy_adapters/connection_handling"
  ActiveRecord::Base.extend(ActiveRecordProxyAdapters::ConnectionHandling)
end

# in your base model
class ApplicationRecord << ActiveRecord::Base
    establish_connection(
        {
            adapter: 'postgresql_proxy',
            # your primary credentials here
        },
        role: :writing
    )

    establish_connection(
        {
            adapter: 'postgresql',
            # your replica credentials here
        },
        role: :reading
    )
end
```

## Configuration

The gem comes preconfigured out of the box. However, if default configuration does not suit your needs, you can modify them by using a `.configure` block:

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

### Sticking to the primary database manually

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
    # so we manually reroute it to the replica
    user = ApplicationRecord.connected_to(role: :writing) { User.find(user_id) }

    UserMailer.welcome(user).deliver_now
  end
end
```

### Thread safety

Since Rails already leases exactly one connection per thread from the pool and the adapter operates on that premise, it is safe to use it in multi-threaded servers such as Puma.

As long as you're not writing thread unsafe code that handles connections from the pool directly, or you don't have any other gem depenencies that write thread unsafe pool operations, you're all set.

There is, however, an open bug in `ActiveRecord::ConnectionAdapters::PostgreSQLAdapter` for Rails versions 7.1 and greater that can cause random race conditions, but it's not caused by this gem (More info [here](https://github.com/rails/rails/issues/51780)).
Rails 7.0 works as expected.

Multi-threaded queries example:
```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :primary, reading: :primary_replica }
end

# app/models/portal.rb
class Portal < ApplicationRecord
end

# in rails console -e test
ActiveRecord::Base.logger.formatter = proc do |_severity, _time, _progname, msg|
  "[#{Time.current.iso8601} THREAD #{Thread.current[:name]}] #{msg}\n"
end

def read_your_own_writes
  proc do
    Portal.all.count # should go to the replica
    FactoryBot.create(:portal)

    5.times do
      Portal.all.count # first one goes the primary, last 3 should go to the replica
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
[2024-12-24T13:52:40-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQLProxy Primary] Portal Exists? (1.2ms)  SELECT 1 AS one FROM "portals" WHERE "portals"."id" IS NOT NULL AND "portals"."slug" = $1 LIMIT $2  [["slug", "portal-e065948fbbee73d3b2c576b48c2b37e021115158edc6a92390d613640460e1d4"], ["LIMIT", 1]]
[2024-12-24T13:52:40-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQLProxy Primary] Portal Exists? (0.4ms)  SELECT 1 AS one FROM "portals" WHERE "portals"."name" = $1 LIMIT $2  [["name", "Portal-e065948fbbee73d3b2c576b48c2b37e021115158edc6a92390d613640460e1d4"], ["LIMIT", 1]]
[2024-12-24T13:52:40-05:00 THREAD READ YOUR OWN WRITES]   [PostgreSQLProxy Primary] Portal Create (0.8ms)  INSERT INTO "portals" ("name", "slug", "logo", "created_at", "updated_at", "visible") VALUES ($1, $2, $3, $4, $5, $6) RETURNING "id"  [["name", "Portal-e065948fbbee73d3b2c576b48c2b37e021115158edc6a92390d613640460e1d4"], ["slug", "portal-e065948fbbee73d3b2c576b48c2b37e021115158edc6a92390d613640460e1d4"], ["logo", nil], ["created_at", "2024-12-24 18:52:40.428383"], ["updated_at", "2024-12-24 18:52:40.428383"], ["visible", true]]
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

TODO: update instructions

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nasdaq/active_record_proxy_adapters. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/nasdaq/active_record_proxy_adapters/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActiveRecordProxyAdapters project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/nasdaq/active_record_proxy_adapters/blob/main/CODE_OF_CONDUCT.md).
