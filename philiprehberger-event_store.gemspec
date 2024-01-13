# frozen_string_literal: true

require_relative 'lib/philiprehberger/event_store/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-event_store'
  spec.version = Philiprehberger::EventStore::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']

  spec.summary = 'In-memory event store with streams, projections, and subscriptions'
  spec.description = 'Thread-safe in-memory event store for CQRS patterns. Supports named streams, ' \
                     'event appending, stream reading, subscriber notifications, and state projections.'
  spec.homepage = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-event_store'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/philiprehberger/rb-event-store'
  spec.metadata['changelog_uri'] = 'https://github.com/philiprehberger/rb-event-store/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/philiprehberger/rb-event-store/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
