# frozen_string_literal: true

module Y
  module Actioncable
    module Sync # rubocop:disable Metrics/ModuleLength
      extend ActiveSupport::Concern

      MESSAGE_SYNC = 0
      MESSAGE_AWARENESS = 1
      private_constant :MESSAGE_SYNC, :MESSAGE_AWARENESS

      # Initiate synchronization. Encodes the current state_vector and transmits
      # to the connecting client.
      def initiate
        encoder = Y::Lib0::Encoding.create_encoder
        Y::Lib0::Encoding.write_var_uint(encoder, MESSAGE_SYNC)
        Y::Sync.write_sync_step1(encoder, doc)
        update = Y::Lib0::Encoding.to_uint8_array(encoder)
        update = Y::Lib0::Encoding.encode_uint8_array_to_base64(update)

        transmit({ update: update })
        # TODO: implement awareness https://github.com/yjs/y-websocket/blob/master/bin/utils.js#L278-L284
      end

      # This methods should be passed as a block to stream subscription, and not
      # be put into a generic #receive method.
      #
      # @param [Y::Doc] doc
      # @param [Hash] message The encoded message must include a field named
      #   exactly like the field argument. The field value must be a Base64
      #   binary.
      # @param [String] field The field that the encoded update should be
      #   extracted from.
      def integrate(message, field: "update")
        origin = message["origin"]
        update = Y::Lib0::Decoding.decode_base64_to_uint8_array(message["update"])

        encoder = Y::Lib0::Encoding.create_encoder
        decoder = Y::Lib0::Decoding.create_decoder(update)
        message_type = Y::Lib0::Decoding.read_var_uint(decoder)
        case message_type
        when MESSAGE_SYNC
          Y::Lib0::Encoding.write_var_uint(encoder, MESSAGE_SYNC)
          Y::Sync.read_sync_message(decoder, encoder, doc, nil)

          # If the `encoder` only contains the type of reply message and no
          # message, there is no need to send the message. When `encoder` only
          # contains the type of reply, its length is 1.
          if Y::Lib0::Encoding.length(encoder) > 1
            update = Y::Lib0::Encoding.to_uint8_array(encoder)
            update = Y::Lib0::Encoding.encode_uint8_array_to_base64(update)

            transmit({ update: update })
          end
        when MESSAGE_AWARENESS
          # TODO: implement awareness https://github.com/yjs/y-websocket/blob/master/bin/utils.js#L179-L181
        end

        # do not transmit message back to current connection if the connection
        # is the origin of the message
        transmit(message) if origin != connection.connection_identifier
      end

      def sync_to(to, message, field: "update")
        update = message["update"]

        # we broadcast to all connected clients, but provide the
        # connection_identifier as origin so that the [#integrate] method is
        # able to filter sending back the update to its origin.
        self.class.broadcast_to(
          to,
          { update: update, origin: connection.connection_identifier }
        )
      end

      # Produce a canonical key for this channel and its parameters. This allows
      # us to create unique documents for separate use cases. e.g. an Issue is
      # the document scope, but has multiple fields that are synchronized, the
      # title, description, labels, …
      #
      # By default, the key is the same as the channel identifier.
      #
      # @example Create a new IssueChannel that sync updates for issue ID
      #   # issue_channel.rb
      #   class IssueChannel
      #     include Y::Actionable::SyncChannel
      #   end
      #
      #   # issue_subscription.js
      #   const params = { id: 1 }
      #   consumer.subscriptions.create(
      #       {channel: "IssueChannel", ...params}
      #   );
      #
      #   # example for a resulting canonical key
      #   "issue_channel:id:1"
      def canonical_channel_key
        @canonical_channel_key ||= begin
          pairs = JSON.parse!(identifier)
          params_part = pairs.map do |k, v|
            "#{k.to_s.parameterize}-#{v.to_s.parameterize}"
          end

          "sync:#{params_part.join(":")}"
        end
      end

      def load(&block)
        full_diff = yield(canonical_channel_key)
        doc.sync(full_diff) unless full_diff.nil?
      end

      def persist(&block)
        yield(canonical_channel_key, doc.diff)
      end

      def doc
        @doc ||= Y::Doc.new
      end
    end
  end
end
