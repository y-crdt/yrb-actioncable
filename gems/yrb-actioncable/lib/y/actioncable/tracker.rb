# frozen_string_literal: true

module Y
  module Actioncable
    class Tracker

      TRACKER_KEY_PREFIX = "tracker"
      private_constant :TRACKER_KEY_PREFIX

      # @attr_reader [String] id
      # @attr_reader [Redis] adapter
      attr_reader :id, :adapter

      # Create new tracker
      #
      # @param [String] id
      # @param [::Redis] adapter
      def initialize(id, adapter:)
        @id = id
        @adapter = adapter
      end

      # Add a connection to tracker
      #
      # @param [::ActionCable::Connection] connection
      def add(connection)
        adapter.zadd(tracker_key, 0.to_f, connection.connection_identifier)

        nil
      end

      # Remove a connection from tracker
      #
      # @param [::ActionCable::Connection] connection
      def remove(connection)
        adapter.zrem(tracker_key, connection.connection_identifier)

        nil
      end

      # Move the offset of the given connection
      #
      # @param [::ActionCable::Connection] connection
      # @param [Integer] offset
      def move(connection, offset)
        adapter.zadd(
          tracker_key,
          offset.to_f,
          connection.connection_identifier,
          gt: true
        )

        nil
      end

      # Return minimum offset currently present in the tracker
      #
      # @return [Integer]
      def min
        result = adapter.zrangebyscore(
          tracker_key,
          "-inf",
          "+inf",
          with_scores: true,
          limit: [0, 1]
        )

        return 0 unless result

        result.first[1].to_i
      end

      private

      def tracker_key
        "#{TRACKER_KEY_PREFIX}:#{id}"
      end
    end
  end
end
