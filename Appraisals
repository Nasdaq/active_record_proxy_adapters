# frozen_string_literal: true

appraise "ar-7.0" do
  gem "activerecord-trilogy-adapter"
  gem "activerecord", "~> 7.0.0"
  gem "activesupport", "~> 7.0.0"
  gem "bigdecimal"
  gem "concurrent-ruby", "1.3.4"
  gem "mutex_m"
  gem "sqlite3", "~> 1.4", force_ruby_platform: true
end

appraise "ar-7.1" do
  gem "activerecord", "~> 7.1.0"
  gem "activesupport", "~> 7.1.0"
  gem "sqlite3", "~> 1.4", force_ruby_platform: true
end

appraise "ar-7.2" do
  gem "activerecord", "~> 7.2.0"
  gem "activesupport", "~> 7.2.0"
  gem "sqlite3", "~> 1.4", force_ruby_platform: true
end

if RUBY_VERSION != "3.1.6"
  appraise "ar-8.0" do
    gem "activerecord", "~> 8.0.0"
    gem "activesupport", "~> 8.0.0"
    gem "sqlite3", "~> 2.1"
  end
end
