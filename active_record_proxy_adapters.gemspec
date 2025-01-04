# frozen_string_literal: true

require_relative "lib/active_record_proxy_adapters/version"

Gem::Specification.new do |spec|
  spec.name = "active_record_proxy_adapters"
  spec.version = ActiveRecordProxyAdapters::VERSION
  spec.authors = ["Matt Cruz"]
  spec.email = ["matt.cruz@nasdaq.com"]

  spec.summary = "Read replica proxy adapters for ActiveRecord!"
  spec.description = <<~TEXT.strip
    This gem allows automatic connection switching between a primary and one read replica database in ActiveRecord.
    It pattern matches the SQL statement being sent to decide whether it should go to the replica (SELECT) or the
    primary (INSERT, UPDATE, DELETE).
  TEXT

  spec.homepage = "https://github.com/Nasdaq/active_record_proxy_adapters"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/Nasdaq/active_record_proxy_adapters/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .gitlab-ci.yml appveyor Gemfile Rakefile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  rails_version_restrictions = [">= 7.0.0", "< 8.1"]

  spec.add_dependency "activerecord", rails_version_restrictions
  spec.add_dependency "activesupport", rails_version_restrictions

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
