# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::EventStore do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::EventStore::VERSION).not_to be_nil
    end
  end

  describe '.new' do
    it 'creates a Store instance' do
      store = described_class.new
      expect(store).to be_a(Philiprehberger::EventStore::Store)
    end
  end

  describe '#append and #read' do
    let(:store) { described_class.new }

    it 'appends and reads events from a stream' do
      store.append(:orders, { type: 'placed' })
      store.append(:orders, { type: 'shipped' })

      events = store.read(:orders)
      expect(events.length).to eq(2)
      expect(events.first[:type]).to eq('placed')
      expect(events.last[:type]).to eq('shipped')
    end

    it 'returns empty array for unknown stream' do
      expect(store.read(:unknown)).to eq([])
    end

    it 'keeps streams isolated' do
      store.append(:orders, { type: 'order' })
      store.append(:users, { type: 'user' })

      expect(store.read(:orders).length).to eq(1)
      expect(store.read(:users).length).to eq(1)
    end

    it 'accepts string stream names' do
      store.append('orders', { type: 'placed' })
      expect(store.read('orders').length).to eq(1)
    end

    it 'returns a copy of events' do
      store.append(:orders, { type: 'placed' })
      events = store.read(:orders)
      events.clear
      expect(store.read(:orders).length).to eq(1)
    end

    it 'treats symbol and string stream names as equivalent' do
      store.append(:orders, { type: 'symbol' })
      store.append('orders', { type: 'string' })
      expect(store.read(:orders).length).to eq(2)
      expect(store.read('orders').length).to eq(2)
    end

    it 'returns self from append for chaining' do
      result = store.append(:stream, { a: 1 })
      expect(result).to eq(store)
    end

    it 'chains multiple appends' do
      store.append(:s, { a: 1 }).append(:s, { b: 2 }).append(:s, { c: 3 })
      expect(store.read(:s).length).to eq(3)
    end

    it 'preserves event ordering' do
      5.times { |i| store.append(:seq, { index: i }) }
      events = store.read(:seq)
      expect(events.map { |e| e[:index] }).to eq([0, 1, 2, 3, 4])
    end

    it 'stores any event type' do
      store.append(:misc, 'plain string')
      store.append(:misc, 42)
      store.append(:misc, [1, 2, 3])
      events = store.read(:misc)
      expect(events).to eq(['plain string', 42, [1, 2, 3]])
    end
  end

  describe '#read_all' do
    let(:store) { described_class.new }

    it 'returns all events across streams' do
      store.append(:orders, { type: 'order' })
      store.append(:users, { type: 'user' })
      store.append(:orders, { type: 'order2' })

      all = store.read_all
      expect(all.length).to eq(3)
    end

    it 'returns empty array when no events exist' do
      expect(store.read_all).to eq([])
    end

    it 'includes events from all streams' do
      store.append(:a, 'event_a')
      store.append(:b, 'event_b')
      store.append(:c, 'event_c')
      all = store.read_all
      expect(all).to include('event_a', 'event_b', 'event_c')
    end
  end

  describe '#subscribe' do
    let(:store) { described_class.new }

    it 'notifies subscribers on append' do
      received = []
      store.subscribe(:orders) { |e| received << e }

      store.append(:orders, { type: 'placed' })
      expect(received.length).to eq(1)
      expect(received.first[:type]).to eq('placed')
    end

    it 'supports multiple subscribers' do
      count = 0
      store.subscribe(:orders) { |_e| count += 1 }
      store.subscribe(:orders) { |_e| count += 1 }

      store.append(:orders, { type: 'placed' })
      expect(count).to eq(2)
    end

    it 'only notifies subscribers of the matching stream' do
      received = []
      store.subscribe(:orders) { |e| received << e }

      store.append(:users, { type: 'user' })
      expect(received).to be_empty
    end

    it 'notifies for each event appended' do
      received = []
      store.subscribe(:orders) { |e| received << e }

      store.append(:orders, { type: 'a' })
      store.append(:orders, { type: 'b' })
      store.append(:orders, { type: 'c' })
      expect(received.length).to eq(3)
    end

    it 'returns self for chaining' do
      result = store.subscribe(:orders) { |_e| nil }
      expect(result).to eq(store)
    end

    it 'does not notify for events before subscription' do
      store.append(:orders, { type: 'before' })

      received = []
      store.subscribe(:orders) { |e| received << e }
      expect(received).to be_empty
    end

    it 'handles subscribers on different streams independently' do
      orders_received = []
      users_received = []
      store.subscribe(:orders) { |e| orders_received << e }
      store.subscribe(:users) { |e| users_received << e }

      store.append(:orders, 'order_event')
      store.append(:users, 'user_event')

      expect(orders_received).to eq(['order_event'])
      expect(users_received).to eq(['user_event'])
    end
  end

  describe '#project' do
    let(:store) { described_class.new }

    it 'projects events into accumulated state' do
      store.append(:orders, { type: 'placed', total: 10 })
      store.append(:orders, { type: 'placed', total: 20 })
      store.append(:orders, { type: 'cancelled' })

      total = store.project(:orders, initial: 0) do |sum, event|
        event[:type] == 'placed' ? sum + event[:total] : sum
      end

      expect(total).to eq(30)
    end

    it 'returns initial value for empty stream' do
      result = store.project(:empty, initial: []) { |state, _e| state }
      expect(result).to eq([])
    end

    it 'handles nil initial value' do
      store.append(:test, { value: 42 })
      result = store.project(:test, initial: nil) { |_state, e| e[:value] }
      expect(result).to eq(42)
    end

    it 'builds a list via projection' do
      store.append(:items, { name: 'a' })
      store.append(:items, { name: 'b' })
      store.append(:items, { name: 'c' })

      names = store.project(:items, initial: []) do |acc, event|
        acc + [event[:name]]
      end
      expect(names).to eq(%w[a b c])
    end

    it 'builds a hash via projection' do
      store.append(:config, { key: 'host', value: 'localhost' })
      store.append(:config, { key: 'port', value: 5432 })

      result = store.project(:config, initial: {}) do |acc, event|
        acc.merge(event[:key] => event[:value])
      end
      expect(result).to eq({ 'host' => 'localhost', 'port' => 5432 })
    end
  end

  describe '#streams' do
    let(:store) { described_class.new }

    it 'returns all stream names' do
      store.append(:orders, {})
      store.append(:users, {})

      expect(store.streams).to contain_exactly('orders', 'users')
    end

    it 'returns empty array when no streams exist' do
      expect(store.streams).to eq([])
    end

    it 'does not include duplicate stream names' do
      store.append(:orders, { a: 1 })
      store.append(:orders, { b: 2 })
      expect(store.streams).to eq(['orders'])
    end

    it 'returns a copy of stream names' do
      store.append(:orders, {})
      names = store.streams
      names.clear
      expect(store.streams).to eq(['orders'])
    end
  end

  describe '#query' do
    let(:store) { described_class.new }

    it 'returns all events when no filters' do
      store.append(:orders, { type: 'created', id: 1 })
      store.append(:orders, { type: 'shipped', id: 1 })
      expect(store.query.size).to eq(2)
    end

    it 'filters by stream' do
      store.append(:orders, { id: 1 })
      store.append(:users, { id: 2 })
      expect(store.query(stream: :orders).size).to eq(1)
    end

    it 'filters by type string' do
      store.append(:orders, { type: 'created', id: 1 })
      store.append(:orders, { type: 'shipped', id: 1 })
      result = store.query(type: 'created')
      expect(result.size).to eq(1)
      expect(result.first[:type]).to eq('created')
    end

    it 'limits results' do
      5.times { |i| store.append(:events, { n: i }) }
      expect(store.query(limit: 3).size).to eq(3)
    end

    it 'returns empty for non-existent stream' do
      expect(store.query(stream: :nonexistent)).to eq([])
    end
  end

  describe '#snapshot and #load_from_snapshot' do
    let(:store) { described_class.new }

    it 'saves and loads a snapshot' do
      store.append(:orders, { type: 'created', total: 10 })
      store.append(:orders, { type: 'updated', total: 20 })
      store.snapshot(:orders, { count: 2, total: 20 })

      store.append(:orders, { type: 'updated', total: 30 })

      result = store.load_from_snapshot(:orders) do |state, event|
        { count: state[:count] + 1, total: event[:total] }
      end
      expect(result[:count]).to eq(3)
      expect(result[:total]).to eq(30)
    end

    it 'falls back to full projection when no snapshot exists' do
      store.append(:orders, { total: 10 })
      store.append(:orders, { total: 20 })

      result = store.load_from_snapshot(:orders, initial: 0) do |acc, event|
        acc + event[:total]
      end
      expect(result).to eq(30)
    end
  end

  describe '#replay' do
    let(:store) { described_class.new }

    it 'replays events to subscribers' do
      events = []
      store.subscribe(:orders) { |e| events << e }
      store.append(:orders, { id: 1 })
      store.append(:orders, { id: 2 })
      events.clear

      store.replay(:orders)
      expect(events.size).to eq(2)
    end

    it 'replays from a specific version' do
      events = []
      store.subscribe(:orders) { |e| events << e }
      store.append(:orders, { id: 1 })
      store.append(:orders, { id: 2 })
      store.append(:orders, { id: 3 })
      events.clear

      store.replay(:orders, from_version: 1)
      expect(events.size).to eq(2)
      expect(events.map { |e| e[:id] }).to eq([2, 3])
    end
  end

  describe '#replay_all' do
    let(:store) { described_class.new }

    it 'replays all events across streams' do
      order_events = []
      user_events = []
      store.subscribe(:orders) { |e| order_events << e }
      store.subscribe(:users) { |e| user_events << e }
      store.append(:orders, { id: 1 })
      store.append(:users, { id: 2 })
      order_events.clear
      user_events.clear

      store.replay_all
      expect(order_events.size).to eq(1)
      expect(user_events.size).to eq(1)
    end
  end

  describe '#version' do
    let(:store) { described_class.new }

    it 'returns 0 for empty stream' do
      expect(store.version(:orders)).to eq(0)
    end

    it 'returns event count' do
      store.append(:orders, { id: 1 })
      store.append(:orders, { id: 2 })
      expect(store.version(:orders)).to eq(2)
    end
  end

  describe '#clear' do
    let(:store) { described_class.new }

    it 'removes events for the given stream but leaves other streams intact' do
      store.append(:orders, { id: 1 })
      store.append(:orders, { id: 2 })
      store.append(:users, { id: 3 })

      store.clear(:orders)

      expect(store.read(:orders)).to eq([])
      expect(store.read(:users).length).to eq(1)
    end

    it 'is a no-op when the stream does not exist' do
      expect { store.clear(:nonexistent) }.not_to raise_error
      expect(store.clear(:nonexistent)).to eq(0)
    end

    it 'empties all streams and snapshots when called with no argument' do
      store.append(:orders, { id: 1 })
      store.append(:users, { id: 2 })
      store.snapshot(:orders, { count: 1 })

      store.clear

      expect(store.read(:orders)).to eq([])
      expect(store.read(:users)).to eq([])
      expect(store.streams).to eq([])
      expect(store.load_from_snapshot(:orders, initial: :none) { |s, _e| s }).to eq(:none)
    end

    it 'retains subscribers after clearing a specific stream' do
      received = []
      store.subscribe(:orders) { |e| received << e }
      store.append(:orders, { id: 1 })

      store.clear(:orders)
      store.append(:orders, { id: 2 })

      expect(received.map { |e| e[:id] }).to eq([1, 2])
    end

    it 'retains subscribers after clearing all streams' do
      received = []
      store.subscribe(:orders) { |e| received << e }
      store.append(:orders, { id: 1 })

      store.clear
      store.append(:orders, { id: 2 })

      expect(received.map { |e| e[:id] }).to eq([1, 2])
    end

    it 'resets the global position after a full clear' do
      store.append(:orders, { id: 1 })
      store.append(:users, { id: 2 })

      store.clear
      store.append(:orders, { id: 3 })

      all = store.query(stream: :orders)
      expect(all.length).to eq(1)
      expect(store.read_all.length).to eq(1)
    end

    it 'removes snapshots for the cleared stream' do
      store.append(:orders, { total: 10 })
      store.snapshot(:orders, { total: 10 })

      store.clear(:orders)

      result = store.load_from_snapshot(:orders, initial: :missing) { |s, _e| s }
      expect(result).to eq(:missing)
    end
  end

  describe 'thread safety' do
    let(:store) { described_class.new }

    it 'handles concurrent appends' do
      threads = 10.times.map do |i|
        Thread.new { 100.times { |j| store.append(:stream, { id: "#{i}-#{j}" }) } }
      end
      threads.each(&:join)

      expect(store.read(:stream).length).to eq(1000)
    end

    it 'handles concurrent reads and writes' do
      threads = []
      threads += 5.times.map do |i|
        Thread.new { 50.times { |j| store.append(:stream, { id: "#{i}-#{j}" }) } }
      end
      threads += 5.times.map do
        Thread.new { 50.times { store.read(:stream) } }
      end
      threads.each(&:join)

      expect(store.read(:stream).length).to eq(250)
    end
  end
end
