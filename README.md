# ActiveRecordProxyAdapters

[![Run Test Suite](https://github.com/Nasdaq/active_record_proxy_adapters/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/Nasdaq/active_record_proxy_adapters/actions/workflows/test.yml)

A set of ActiveRecord adapters that leverage Rails native multiple database setup to allow automatic connection switching from _one_ primary pool to _one_ replica pool at the database statement level.

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

### Configuration

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

### How it works

The proxy will analyze each SQL string, using pattern matching, to decide the appropriate connection for it (i.e. if it should go to the primary or replica).

- All queries inside a transaction go to the primary
- All `SET` queries go to all connections
- All `INSERT`, `UPDATE` and `DELETE` queries go to the primary
- All `SELECT FOR UPDATE` queries go to the primary
- All `lock` queries (e.g `get_lock`) go the primary
- All sequence methods (e.g `nextval`) go the primary
- Everything else goes to the replica

#### TL;DR

All `SELECT` queries go to the _replica_, everything else goes to _primary_.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nasdaq/active_record_proxy_adapters. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/nasdaq/active_record_proxy_adapters/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActiveRecordProxyAdapters project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/nasdaq/active_record_proxy_adapters/blob/main/CODE_OF_CONDUCT.md).
