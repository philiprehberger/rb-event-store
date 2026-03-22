# frozen_string_literal: true

require_relative 'event_store/version'
require_relative 'event_store/store'

module Philiprehberger
  module EventStore
    class Error < StandardError; end

    # Create a new event store instance.
    #
    # @return [Store] a new store
    def self.new
      Store.new
    end
  end
end
