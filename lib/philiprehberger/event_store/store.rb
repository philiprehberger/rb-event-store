# frozen_string_literal: true

module Philiprehberger
  module EventStore
    # Thread-safe in-memory event store with streams, projections, subscriptions,
    # querying, snapshots, and replay.
    class Store
      # Create a new event store.
      def initialize
        @mutex = Mutex.new
        @streams = {}
        @subscribers = {}
        @global_position = 0
        @snapshots = {}
      end

      # Append an event to a stream.
      #
      # @param stream [String, Symbol] the stream name
      # @param event [Object] the event to append
      # @return [self]
      def append(stream, event)
        stream = stream.to_s
        subscribers = nil

        @mutex.synchronize do
          @streams[stream] ||= []
          @global_position += 1
          entry = { event: event, position: @global_position, stream: stream, timestamp: Time.now }
          @streams[stream] << entry
          subscribers = (@subscribers[stream] || []).dup
        end

        subscribers.each { |callback| callback.call(event) }
        self
      end

      # Clear events (and snapshot) for the given stream, or everything when no
      # stream is passed. Subscribers are retained in both cases. Clearing all
      # also resets the global position counter.
      #
      # @param stream [String, Symbol, nil] the stream name, or nil to clear all
      # @return [Integer] the number of events removed
      def clear(stream = nil)
        @mutex.synchronize do
          if stream.nil?
            removed = @streams.values.sum(&:size)
            @streams.clear
            @snapshots.clear
            @global_position = 0
            removed
          else
            key = stream.to_s
            next 0 unless @streams.key?(key)

            removed = @streams[key].size
            @streams.delete(key)
            @snapshots.delete(key)
            removed
          end
        end
      end

      # Read all events from a stream.
      #
      # @param stream [String, Symbol] the stream name
      # @return [Array] events in the stream
      def read(stream)
        stream = stream.to_s
        @mutex.synchronize do
          (@streams[stream] || []).map { |entry| entry[:event] }
        end
      end

      # Read all events from all streams, ordered by global position.
      #
      # @return [Array] all events across all streams
      def read_all
        @mutex.synchronize do
          @streams.values.flatten.sort_by { |entry| entry[:position] }.map { |entry| entry[:event] }
        end
      end

      # Query events with filters.
      #
      # @param stream [String, Symbol, nil] filter by stream name
      # @param type [Class, String, nil] filter by event type (class or string class name)
      # @param after [Time, nil] only events after this time
      # @param before [Time, nil] only events before this time
      # @param limit [Integer, nil] maximum number of events to return
      # @return [Array] matching events
      def query(stream: nil, type: nil, after: nil, before: nil, limit: nil)
        entries = @mutex.synchronize do
          if stream
            (@streams[stream.to_s] || []).dup
          else
            @streams.values.flatten.sort_by { |e| e[:position] }
          end
        end

        entries = entries.select { |e| matches_type?(e[:event], type) } if type
        entries = entries.select { |e| e[:timestamp] > after } if after
        entries = entries.select { |e| e[:timestamp] < before } if before
        entries = entries.first(limit) if limit

        entries.map { |e| e[:event] }
      end

      # Subscribe to events on a stream.
      #
      # @param stream [String, Symbol] the stream name
      # @yield [event] called for each new event appended to the stream
      # @return [self]
      def subscribe(stream, &block)
        stream = stream.to_s
        @mutex.synchronize do
          @subscribers[stream] ||= []
          @subscribers[stream] << block
        end
        self
      end

      # Project events from a stream into an accumulated state.
      #
      # @param stream [String, Symbol] the stream name
      # @param initial [Object] the initial state
      # @yield [state, event] called for each event to produce the next state
      # @return [Object] the final projected state
      def project(stream, initial: nil, &block)
        events = read(stream)
        events.reduce(initial, &block)
      end

      # List all stream names.
      #
      # @return [Array<String>] stream names
      def streams
        @mutex.synchronize { @streams.keys.dup }
      end

      # Save a snapshot of an aggregate's state at the current stream version.
      #
      # @param stream [String, Symbol] the stream name
      # @param state [Object] the aggregate state to snapshot
      # @return [self]
      def snapshot(stream, state)
        stream = stream.to_s
        @mutex.synchronize do
          version = (@streams[stream] || []).size
          @snapshots[stream] = { state: state, version: version }
        end
        self
      end

      # Load state from a snapshot plus any events appended after the snapshot.
      #
      # @param stream [String, Symbol] the stream name
      # @param initial [Object] the initial state if no snapshot exists
      # @yield [state, event] called for each event after the snapshot
      # @return [Object] the rebuilt state
      def load_from_snapshot(stream, initial: nil, &block)
        stream = stream.to_s
        snap = @mutex.synchronize { @snapshots[stream] }

        if snap
          state = snap[:state]
          remaining = @mutex.synchronize do
            entries = @streams[stream] || []
            entries[snap[:version]..].map { |e| e[:event] }
          end
          remaining.reduce(state, &block)
        else
          project(stream, initial: initial, &block)
        end
      end

      # Replay events from a stream to all current subscribers.
      #
      # @param stream [String, Symbol] the stream name
      # @param from_version [Integer] start replaying from this version (0-based index)
      # @return [self]
      def replay(stream, from_version: 0)
        stream = stream.to_s
        events_to_replay = nil
        subscribers = nil

        @mutex.synchronize do
          entries = @streams[stream] || []
          events_to_replay = entries[from_version..].map { |e| e[:event] }
          subscribers = (@subscribers[stream] || []).dup
        end

        events_to_replay.each do |event|
          subscribers.each { |callback| callback.call(event) }
        end

        self
      end

      # Replay all events across all streams to their subscribers.
      #
      # @param from_position [Integer] start from this global position (1-based)
      # @return [self]
      def replay_all(from_position: 1)
        entries_to_replay = nil

        @mutex.synchronize do
          entries_to_replay = @streams.values.flatten
                                      .select { |e| e[:position] >= from_position }
                                      .sort_by { |e| e[:position] }
        end

        entries_to_replay.each do |entry|
          subscribers = @mutex.synchronize { (@subscribers[entry[:stream]] || []).dup }
          subscribers.each { |callback| callback.call(entry[:event]) }
        end

        self
      end

      # Return the current version (event count) of a stream.
      #
      # @param stream [String, Symbol] the stream name
      # @return [Integer]
      def version(stream)
        stream = stream.to_s
        @mutex.synchronize { (@streams[stream] || []).size }
      end

      # Total number of events across all streams.
      #
      # Companion to `#version(stream)` at the whole-store level; useful for
      # dashboard-style total counters.
      #
      # @return [Integer]
      def total_events
        @mutex.synchronize { @streams.values.sum(&:size) }
      end

      private

      def matches_type?(event, type)
        if type.is_a?(Class)
          event.is_a?(type)
        else
          event.is_a?(Hash) ? event[:type].to_s == type.to_s || event['type'].to_s == type.to_s : event.instance_of?(type)
        end
      end
    end
  end
end
