# frozen_string_literal: true

module Y
  module Actioncable
    # A Sync module for Rails ActionCable channels.
    #
    # This module contains a set of utility methods that allows a relatively
    # convenient implementation of a real-time sync channel. The module
    # implements the synchronization steps described in
    # [`y-protocols/sync`](https://github.com/yjs/y-protocols/blob/master/sync.js).
    #
    # @example Create a SyncChannel including this module
    #   class SyncChannel
    #     def subscribed
    #       # initiate sync & subscribe to updates, with optional persistence mechanism
    #       sync_for(session) { |id, update| save_doc(id, update) }
    #     end
    #
    #     def receive(message)
    #       # broadcast update to all connected clients on all servers
    #       sync_to(session, message)
    #     end
    #   end
    module Sync
      extend ActiveSupport::Concern

      CHANNEL_PREFIX = "sync"
      FIELD_ORIGIN = "origin"
      FIELD_UPDATE = "update"
      MESSAGE_SYNC = 0
      MESSAGE_AWARENESS = 1
      private_constant(
        :CHANNEL_PREFIX,
        :FIELD_ORIGIN,
        :FIELD_UPDATE,
        :MESSAGE_SYNC,
        :MESSAGE_AWARENESS
      )

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
      # @param [Hash] message The encoded message must include a field named
      #   exactly like the field argument. The field value must be a Base64
      #   binary.
      # @param [String] field The field that the encoded update should be
      #   extracted from.
      def integrate(message, field: FIELD_UPDATE) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        origin = message[FIELD_ORIGIN]
        update = Y::Lib0::Decoding.decode_base64_to_uint8_array(message[field])

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
        else
          raise "unexpected message_type=`#{message_type}`"
        end

        # do not transmit message back to current connection if the connection
        # is the origin of the message
        transmit(message) if origin != connection.connection_identifier
      end

      # Sync for given model. This is a utility method that simplifies the setup
      # of a sync channel.
      #
      # @param [Object] model
      #
      # for block { |id, update| … }
      # @yield [id, update] Optional block that allows to persist the document
      #
      # @yieldparam [String] id The document ID
      # @yieldparam [Array<Integer>] update The full document state as binary
      #   encoded update
      def sync_for(model, &block)
        stream_for(model, coder: ActiveSupport::JSON) do |message|
          # integrate updates in the y-rb document
          integrate(message)

          # persist document
          persist(&block) if block
        end

        # negotiate initial state with client
        initiate
      end

      # Sync for given stream. This is a utility method that simplifies the
      # setup of a sync channel.
      #
      # @param [String] broadcasting
      #
      # for block { |id, update| … }
      # @yield [id, update] Optional block that allows to persist the document
      #
      # @yieldparam [String] id The document ID
      # @yieldparam [Array<Integer>] update The full document state as binary
      #   encoded update
      def sync_from(broadcasting, &block)
        stream_from(broadcasting, coder: ActiveSupport::JSON) do |message|
          # integrate updates in the y-rb document
          integrate(message)

          # persist document
          persist(&block) if block
        end

        # negotiate initial state with client
        initiate
      end

      # Synchronize update with all other connected clients (and server
      # processes).
      #
      # @param [String] broadcasting
      # @param [Hash] message
      # @param [optional, String] field
      def sync(broadcasting, message, field: FIELD_UPDATE)
        update = message[field]

        # we broadcast to all connected clients, but provide the
        # connection_identifier as origin so that the [#integrate] method is
        # able to filter sending back the update to its origin.
        self.class.broadcast(
          broadcasting,
          { update: update, origin: connection.connection_identifier }
        )
      end

      # Synchronize update with all other connected clients (and server
      # processes).
      #
      # @param [Object] to
      # @param [Hash] message
      # @param [optional, String] field
      def sync_to(to, message, field: FIELD_UPDATE)
        update = message[field]

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
          params_part = channel_identifier.map do |k, v|
            "#{k.to_s.parameterize}-#{v.to_s.parameterize}"
          end

          "#{CHANNEL_PREFIX}:#{params_part.join(":")}"
        end
      end

      # Load the current state of a document from an external source and returns
      # a reference to the document.
      #
      # for block { |id| … }
      # @yield [id] Read document from e.g. an external store
      #
      # @yieldparam [String] id The document ID
      # @yieldreturn [Array<Integer>] The binary encoded state of the document
      # @return [Y::Doc] A reference to the loaded document
      def load(&block)
        full_diff = nil
        full_diff = yield(canonical_channel_key) if block
        doc.sync(full_diff) unless full_diff.nil?
        doc
      end

      # Persist the current document state to an external store.
      #
      # for block { |id, update| … }
      # @yield [id, update] Store document state to e.g. an external store
      #
      # @yieldparam [String] id The document ID
      # @yieldparam [Array<Integer>] update The full document state as binary
      #   encoded state
      def persist(&block)
        yield(canonical_channel_key, doc.diff) if block
      end

      # Creates the document once.
      #
      # This method can be overriden in case the document should be initialized
      # with any state other than an empty one. In conjunction with
      # {Y::Actioncable::Sync#load load}, this allows to provide a document to
      # clients that is restored from a persistent store like Redis or also an
      # ActiveRecord model.
      #
      # @example Initialize a {Y::Doc} from state stored in Redis
      #   def doc
      #     @doc ||= load { |id| load_doc(id) }
      #   end
      #
      #   def load_doc(id)
      #     data = REDIS.get(id)
      #     data = data.unpack("C*") unless data.nil?
      #     data
      #   end
      #
      # @return [Y::Doc] The initialized document
      def doc
        @doc ||= Y::Doc.new
      end

      private

      def channel_identifier
        return ["test", identifier] if Rails.env.test?

        JSON.parse(identifier)
      end
    end
  end
end
