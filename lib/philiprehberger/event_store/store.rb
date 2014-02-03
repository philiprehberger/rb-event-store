# frozen_string_literal: true

module Philiprehberger
  module EventStore
    # Thread-safe in-memory event store with streams, projections, and subscriptions.
    class Store
      # Create a new event store.
      def initialize
        @mutex = Mutex.new
        @streams = {}
        @subscribers = {}
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
          @streams[stream] << event
          subscribers = (@subscribers[stream] || []).dup
        end

        subscribers.each { |callback| callback.call(event) }
        self
      end

      # Read all events from a stream.
      #
      # @param stream [String, Symbol] the stream name
      # @return [Array] events in the stream
      def read(stream)
        stream = stream.to_s
        @mutex.synchronize { (@streams[stream] || []).dup }
      end

      # Read all events from all streams, ordered by insertion time.
      #
      # @return [Array] all events across all streams
      def read_all
        @mutex.synchronize do
          @streams.values.flatten
        end
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
    end
  end
end
