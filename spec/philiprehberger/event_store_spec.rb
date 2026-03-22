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
  end
end
