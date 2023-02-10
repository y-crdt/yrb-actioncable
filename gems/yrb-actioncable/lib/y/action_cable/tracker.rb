# frozen_string_literal: true

module Y
  module ActionCable
    class Tracker
      TRACKER_KEY_PREFIX = "tracker"
      private_constant :TRACKER_KEY_PREFIX

      # @attr_reader [String] id
      # @attr_reader [Y::ActionCable::SyncAdapter::Base] adapter
      attr_reader :id, :adapter

      # Create new tracker
      #
      # @param [String] id
      # @param [Y::ActionCable::SyncAdapter::Base] adapter
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

      # Remove all connections except the ones provided via the except argument
      def remove_all
        adapter.remove_all(tracker_key)

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

      # Create a tracker key
      #
      # @return [String]
      def tracker_key
        "#{TRACKER_KEY_PREFIX}:#{id}"
      end
    end
  end
end
