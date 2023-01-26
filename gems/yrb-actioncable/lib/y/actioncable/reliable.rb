# frozen_string_literal: true

module Y
  module Actioncable
    # This module adds reliable messaging for channels.
    #
    # The methods provided in this module are helpers to establish
    # at-least-once delivery guarantees for message transport between client
    # and server. A `Reliable` client is requested to re-send a message until
    # the server acknowledges retrieval. For messages sent from the server to
    # the client, the protocol is slightly different. It does not require
    # re-sending the message, but the client can request "older" messages in
    # case there are missing updates.
    #
    # The server "tracks" message offsets for each individual connection until
    # a disconnect event occurs. All the messages are stored into a Redis stream
    # per channel and parameter pair, the
    # {Y::Actioncable::Sync#canonical_channel_key canonical_channel_key}. We
    # eventually truncate (GC) the stream up to the minimum offset value for the
    # given stream. Therefore streams aren't suitable to persist updates
    # forever. They are also not meant to be used as a concept that allows to
    # go back in history.
    module Reliable
      extend ActiveSupport::Concern

      CHANNEL_RELIABLE_PREFIX = "reliable"
      private_constant :CHANNEL_RELIABLE_PREFIX

      # Sets up a reliable subscription for the current connection. This should
      # be used in the {Rails::ActionCable::Channel#subscribed} method.
      def self.reliable_subscription; end

      # Append message and return entry ID
      #
      # @param [Hash] message
      # @return [String] The entry ID
      def append(message)
        adapter.xadd(reliable_channel_key, message)
      end

      # Truncate the message log up until the given offset
      #
      # @param [String] offset
      def truncate(offset)
        adapter.xtrim(reliable_channel_key, offset, strategy: "MINID")

        nil
      end

      private

      def reliable_channel_key
        @reliable_channel_key ||= begin
          params_part = channel_identifier.map do |k, v|
            "#{k.to_s.parameterize}-#{v.to_s.parameterize}"
          end

          "#{CHANNEL_RELIABLE_PREFIX}:#{params_part.join(":")}"
        end
      end

      def channel_identifier
        return ["test", identifier] if Rails.env.test?

        JSON.parse(identifier)
      end

      # @return [Y::Actioncable::Tracker]
      def tracker
        id = channel_identifier.map do |k, v|
          "#{k.to_s.parameterize}-#{v.to_s.parameterize}"
        end
        id = id.join(":")

        @tracker ||= Y::Actioncable::Tracker.new(id, adapter: adapter)
      end

      # @return [::Redis] The adapter used to track messages and client offsets
      def adapter
        @adapter ||= begin
          redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
          Redis.new(url: redis_url)
        end
      end
    end
  end
end
