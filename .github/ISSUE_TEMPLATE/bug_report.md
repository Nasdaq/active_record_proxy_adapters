---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug
assignees: mateuscruz

---

**Describe the bug**
A clear and concise description of what the bug is.

### Steps to reproduce

```ruby
# Please include an inline gemfile with the *minimum* set of dependencies to reproduce the bug.
# We don't need your application's full gemfile.
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'activerecord', 'your_version_here'
  gem 'active_record_proxy_adapters', 'your_version_here'
end

# Your database config, active record models and reproduction script go here
# Please use environment variables for the database config
```

### Expected behavior

<!-- Tell us what should happen -->

### Actual behavior

<!-- Tell us what happens instead -->

### System configuration
**Active Record version**: 
**Active Record proxy adapters version**: 
**Ruby version**:
