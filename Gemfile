# frozen_string_literal: true

source "https://rubygems.org"

gem "connection_pool", "< 3"
gem "dalli"
gem "mysql2", "~> 0.5"
gem "pg", "~> 1.6"
gem "rake", "~> 13.3"
gem "redis", "~> 5.4.1"
gem "trilogy", "~> 2.10"

gem "appraisal"

# Gems that used to be default gems in Ruby 3.7.x but aren't anymore
gem "benchmark"
gem "logger"
gem "readline"

gem "pry", "~> 0.16.0"

# for documentation server
gem "puma"
gem "rack", "~> 2.2.21"
gem "yard"

group :test do
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.82"
  gem "rubocop-rspec", "~> 3.9.0"
  gem "simplecov"
  gem "timecop"
end

# Specify your gem's dependencies in active_record_proxy_adapters.gemspec
gemspec
