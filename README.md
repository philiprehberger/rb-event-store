# philiprehberger-event_store

[![Tests](https://github.com/philiprehberger/rb-event-store/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-event-store/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-event_store.svg)](https://rubygems.org/gems/philiprehberger-event_store)
[![License](https://img.shields.io/github/license/philiprehberger/rb-event-store)](LICENSE)

In-memory event store with streams, projections, and subscriptions

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

### Reading All Events

```ruby
store.read_all    # => all events across all streams
store.streams     # => ['orders', ...]
```

## API

| Method | Description |
|--------|-------------|
| `.new` | Create a new event store |
| `#append(stream, event)` | Append an event to a stream |
| `#read(stream)` | Read all events from a stream |
| `#read_all` | Read all events across all streams |
| `#subscribe(stream) { \|e\| }` | Subscribe to new events on a stream |
| `#project(stream, initial:) { \|state, e\| }` | Project events into accumulated state |
| `#streams` | List all stream names |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
