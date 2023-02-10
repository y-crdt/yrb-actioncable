# frozen_string_literal: true

module Y
  module ActionCable
    module Sync
      module Reliable
        extend ActiveSupport::Concern

        CHANNEL_RELIABLE_PREFIX = "reliable"
        private_constant :CHANNEL_RELIABLE_PREFIX

        included do
          # garbage collect stream
          periodically :truncate, every: 2.seconds

          # handler
          add_sync_handler :append_and_ack

          # add connection to tracker
          after_subscribe :add

          # remove connection from tracker
          before_unsubscribe :remove
        end

        # Acknowledge messages retrieval by the client.
        #
        # @param [Hash] message
        def ack(message)
          id = message[Field::ID]

          tracker.move(connection, id)

          nil
        end

        private

        # Add a connection to the tracker
        def add
          tracker.add(connection)

          nil
        end

        # Append message and return entry ID
        #
        # @param [Hash] message
        # @return [String] The entry ID
        def append(message)
          adapter.append(reliable_channel_key, message)
        end

        # Append message to stream and acknowledge message retrieval
        #
        # @param [Hash] message
        def append_and_ack(message) # rubocop:disable Metrics/MethodLength
          # append message to stream
          entry_id = append(message)

          # Sent back an acknowledge signal to client, but only to the client
          # that sent the update
          origin = message[Field::ORIGIN]
          connection_identifier = connection.connection_identifier
          if  connection_identifier.present? && origin.present? &&
              origin == connection_identifier
            transmit({ op: Op::ACK, clock: message[Field::CLOCK] })
          end

          nil
        end

        # Remove connection from tracker
        def remove
          tracker.remove(connection)

          nil
        end

        # Creates a tracker instance if does not exist and always returns an
        # instance of a {Y::ActionCable::Tracker#new}.
        #
        # @return [Y::ActionCable::Tracker]
        def tracker
          id = channel_identifier.map do |k, v|
            "#{k.to_s.parameterize}-#{v.to_s.parameterize}"
          end
          id = id.join(":")

          @tracker ||= Y::ActionCable::Tracker.new(id, adapter: adapter)
        end

        # Truncate the message log up until the given offset
        def truncate
          # make sure that connections that are no longer active, are no longer
          # tracked. We have to use a heuristic, as we cannot be sure when a
          # client disconnects (e.g. app server crash would not trigger an
          # unsubscribe event).
          tracker.remove_all

          # truncate stream based of the minimum entry_id of all connections
          offset = tracker.min
          adapter.truncate(reliable_channel_key, offset)

          nil
        end

        # Returns a deterministic channel key
        #
        # @return [String]
        def reliable_channel_key
          @reliable_channel_key ||= begin
            params_part = channel_identifier.map do |k, v|
              "#{k.to_s.parameterize}-#{v.to_s.parameterize}"
            end

            "#{CHANNEL_RELIABLE_PREFIX}:#{params_part.join(":")}"
          end
        end

        # Returns a deterministic channel identifier
        #
        # @return [String]
        def channel_identifier
          return ["test", identifier] if Rails.env.test?

          JSON.parse(identifier)
        end

        # Instantiate (if not initialized) a reliable sync adapter and always
        # return instance.
        #
        # @return [Y::ActionCable::SyncAdapter::Base]
        #   The adapter used to track messages and client offsets
        def adapter
          @adapter ||= Y::ActionCable.config.sync_adapter.new(
            Y::ActionCable.config.sync
          )
        end
      end
    end
  end
end
