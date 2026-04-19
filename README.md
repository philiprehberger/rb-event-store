# philiprehberger-event_store

[![Tests](https://github.com/philiprehberger/rb-event-store/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-event-store/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-event_store.svg)](https://rubygems.org/gems/philiprehberger-event_store)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-event-store)](https://github.com/philiprehberger/rb-event-store/commits/main)

In-memory event store with streams, projections, subscriptions, snapshots, and replay

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-event_store"
```

Or install directly:

```bash
gem install philiprehberger-event_store
```

## Usage

```ruby
require "philiprehberger/event_store"

store = Philiprehberger::EventStore.new

store.append(:orders, { type: 'OrderPlaced', id: 1, total: 99.99 })
store.append(:orders, { type: 'OrderShipped', id: 1 })

store.read(:orders)
# => [{ type: 'OrderPlaced', ... }, { type: 'OrderShipped', ... }]
```

### Subscriptions

```ruby
store.subscribe(:orders) do |event|
  puts "New order event: #{event[:type]}"
end

store.append(:orders, { type: 'OrderCancelled', id: 2 })
# prints: New order event: OrderCancelled
```

### Projections

```ruby
total = store.project(:orders, initial: 0) do |sum, event|
  event[:type] == 'OrderPlaced' ? sum + event[:total] : sum
end
# => 99.99
```

### Event Querying

```ruby
# Filter by stream
store.query(stream: :orders)

# Filter by event type
store.query(type: 'OrderPlaced')

# Combine filters with time range and limit
store.query(stream: :orders, after: 1.hour.ago, limit: 10)
```

### Snapshots

Save aggregate state at a point in time, then rebuild from the snapshot plus newer events:

```ruby
# Build state from events
state = store.project(:orders, initial: { count: 0, total: 0 }) do |s, e|
  { count: s[:count] + 1, total: s[:total] + (e[:total] || 0) }
end

# Save a snapshot
store.snapshot(:orders, state)

# Later, after more events have been appended:
store.append(:orders, { type: 'OrderPlaced', total: 50 })

# Rebuild from snapshot + new events (avoids replaying entire history)
rebuilt = store.load_from_snapshot(:orders) do |s, e|
  { count: s[:count] + 1, total: s[:total] + (e[:total] || 0) }
end
```

### Replay

Re-emit past events to current subscribers:

```ruby
# Replay all events in a stream
store.replay(:orders)

# Replay from a specific version (0-based index)
store.replay(:orders, from_version: 5)

# Replay all events across all streams
store.replay_all

# Replay from a global position
store.replay_all(from_position: 100)
```

### Clearing streams

Remove events (and snapshots) while keeping subscribers registered:

```ruby
received = []
store.subscribe(:orders) { |e| received << e }
store.append(:orders, { type: 'OrderPlaced' })

# Clear a single stream — subscribers stay attached
store.clear(:orders)
store.append(:orders, { type: 'OrderPlaced' })
# subscriber still fires for the new event

# Clear everything — streams and snapshots wiped, subscribers retained,
# global position reset to zero
store.clear
```

### Reading All Events

```ruby
store.read_all        # => all events across all streams, ordered by position
store.streams         # => ['orders', ...]
store.version(:orders) # => 5 (event count in stream)
```

## API

| Method | Description |
|--------|-------------|
| `.new` | Create a new event store |
| `#append(stream, event)` | Append an event to a stream |
| `#read(stream)` | Read all events from a stream |
| `#read_all` | Read all events across all streams |
| `#query(stream:, type:, after:, before:, limit:)` | Query events with filters |
| `#subscribe(stream) { \|e\| }` | Subscribe to new events on a stream |
| `#project(stream, initial:) { \|state, e\| }` | Project events into accumulated state |
| `#snapshot(stream, state)` | Save aggregate state at current stream version |
| `#load_from_snapshot(stream, initial:) { \|state, e\| }` | Rebuild state from snapshot + newer events |
| `#replay(stream, from_version:)` | Replay stream events to subscribers |
| `#replay_all(from_position:)` | Replay all events across streams to subscribers |
| `#version(stream)` | Return event count for a stream |
| `#streams` | List all stream names |
| `#clear(stream = nil)` | Remove events and snapshot for a stream, or everything when no stream is passed (subscribers retained) |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-event-store)

🐛 [Report issues](https://github.com/philiprehberger/rb-event-store/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-event-store/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
