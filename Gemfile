# frozen_string_literal: true

source "https://rubygems.org"

gem "mysql2", "~> 0.5"
gem "pg", "~> 1.5"

gem "rake", "~> 13.0"

gem "concurrent-ruby", "1.3.4" # TODO: delete this line once Rails 7.0 is no longer supported

group :test do
  gem "rspec", "~> 3.0"
  gem "rubocop", "~> 1.21"
  gem "rubocop-rspec", "~> 3.3.0"
  gem "simplecov"
  gem "simplecov-cobertura"
end

if ENV["RAILS_VERSION"]
  gem "activerecord", "~> #{ENV["RAILS_VERSION"]}"
  gem "activesupport", "~> #{ENV["RAILS_VERSION"]}"
end

# Specify your gem's dependencies in active_record_proxy_adapters.gemspec
gemspec
