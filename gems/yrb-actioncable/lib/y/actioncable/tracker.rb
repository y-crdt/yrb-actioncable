# frozen_string_literal: true

module Y
  module Actioncable
    class Tracker
      TRACKER_KEY_PREFIX = "tracker"
      private_constant :TRACKER_KEY_PREFIX

      # @attr_reader [String] id
      # @attr_reader [Y::Actioncable::Adapter::Redis, Y::Actioncable::Adapter::Test] adapter
      attr_reader :id, :adapter

      # Create new tracker
      #
      # @param [String] id
      # @param [Y::Actioncable::Adapter::Redis, Y::Actioncable::Adapter::Test] adapter
      def initialize(id, adapter:)
        @id = id
        @adapter = adapter
      end

      # Add a connection to tracker
      #
      # @param [::ActionCable::Connection] connection
      def add(connection)
        adapter.add(tracker_key, connection.connection_identifier)

        nil
      end

      # Remove a connection from tracker
      #
      # @param [::ActionCable::Connection] connection
      def remove(connection)
        adapter.remove(tracker_key, connection.connection_identifier)

        nil
      end

      # Move the offset of the given connection
      #
      # @param [::ActionCable::Connection] connection
      # @param [Integer] offset
      def move(connection, offset)
        adapter.move(tracker_key, connection.connection_identifier, offset)

        nil
      end

      # Return minimum offset currently present in the tracker
      #
      # @return [Integer]
      def min
        adapter.min(tracker_key)
      end

      private

      def tracker_key
        "#{TRACKER_KEY_PREFIX}:#{id}"
      end
    end
  end
end
