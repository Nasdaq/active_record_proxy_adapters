# frozen_string_literal: true

appraise "ruby-#{RUBY_VERSION}-ar-7.0" do
  gem "activerecord", "~> 7.0.0"
  gem "activesupport", "~> 7.0.0"
  gem "concurrent-ruby", "1.3.4"
  gem "mutex_m"
  gem "bigdecimal"
  gem "activerecord-trilogy-adapter"
end

appraise "ruby-#{RUBY_VERSION}-ar-7.1" do
  gem "activerecord", "~> 7.1.0"
  gem "activesupport", "~> 7.1.0"
end

appraise "ruby-#{RUBY_VERSION}-ar-7.2" do
  gem "activerecord", "~> 7.2.0"
  gem "activesupport", "~> 7.2.0"
end

if RUBY_VERSION != "3.1.6"
  appraise "ruby-#{RUBY_VERSION}-ar-8.0" do
    gem "activerecord", "~> 8.0.0"
    gem "activesupport", "~> 8.0.0"
  end
end
