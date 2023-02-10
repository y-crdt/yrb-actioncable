# frozen_string_literal: true

module Y
  module ActionCable
    module Sync
      module Base
        extend ActiveSupport::Concern

        CHANNEL_PREFIX = "sync"
        private_constant :CHANNEL_PREFIX

        class_methods do # rubocop:disable Metrics/BlockLength
          def add_initiate_handler(handler)
            initiate_handler << handler

            nil
          end

          def add_receive_handler(handler)
            receive_handler << handler

            nil
          end

          def add_sync_handler(handler)
            sync_handler << handler

            nil
          end

          def add_transmit_handler(handler)
            transmit_handler << handler

            nil
          end

          def initiate_handler
            @initiate_handler ||= []
          end

          def receive_handler
            @receive_handler ||= []
          end

          def sync_handler
            @sync_handler ||= []
          end

          def transmit_handler
            @transmit_handler ||= []
          end
        end

        # Handle broadcasted messages
        def receive(message)
          # call handlers
          handle_receive(message)
        end

        # Sync for given model. This is a utility method that simplifies the
        # setup of a sync channel.
        #
        # @param [Object] model
        #
        # for block { |id, update| … }
        # @yield [id, update] Optional block that allows to persist the document
        #
        # @yieldparam [String] id The document ID
        # @yieldparam [Array<Integer>] update The full document state as binary
        #   encoded update
        def sync_for(model, &block) # rubocop:disable Metrics/MethodLength
          stream_for(model, coder: ActiveSupport::JSON) do |message|
            # call handlers
            handle_transmit(message)

            # transmit (if not origin) and map action to op
            origin = message[Field::ORIGIN]
            connection_identifier = connection.connection_identifier
            message[Field::OP] = message[Field::ACTION]
            message.delete(Field::ACTION)
            message.delete(Field::ORIGIN)
            transmit(message) if origin != connection_identifier

            # persist document
            persist(&block) if block
          end

          # negotiate initial state with client
          handle_initiate
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
        def sync_from(broadcasting, &block) # rubocop:disable Metrics/MethodLength
          stream_from(broadcasting, coder: ActiveSupport::JSON) do |message|
            # call handlers
            handle_transmit(message)

            # transmit (if not origin) and map action to op
            origin = message[Field::ORIGIN]
            connection_identifier = connection.connection_identifier
            message[Field::OP] = message[Field::ACTION]
            message.delete(Field::ACTION)
            message.delete(Field::ORIGIN)
            transmit(message) if origin != connection_identifier

            # persist document
            persist(&block) if block
          end

          # negotiate initial state with client
          handle_initiate
        end

        # Synchronize update with all other connected clients (and servers).
        #
        # @param [String] broadcasting
        # @param [Hash] message
        def sync(broadcasting, message)
          # add origin to message
          message[Field::ORIGIN] = connection.connection_identifier

          # we broadcast to all connected clients, but provide the
          # connection_identifier as origin so that the [#integrate] method is
          # able to filter sending back the update to its origin.
          ActionCable.server.broadcast(broadcasting, message)

          # call sync handler
          handle_sync(message)
        end

        # Synchronize update with all other connected clients (and servers).
        #
        # @param [Object] to
        # @param [Hash] message
        def sync_to(to, message)
          # add origin to message
          message[Field::ORIGIN] = connection.connection_identifier

          # we broadcast to all connected clients, but provide the
          # connection_identifier as origin so that the do not send the message
          # back to its origin.
          self.class.broadcast_to(to, message)

          # call sync handler
          handle_sync(message)
        end

        # Load the current state of a document from an external source and
        # returns a reference to the document.
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
          @doc ||= Y::Doc.new
          @doc.sync(full_diff) unless full_diff.nil?
          @doc
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
        # This method can be overridden in case the document should be
        # initialized with any state other than an empty one. In conjunction
        # with {Y::ActionCable::Sync#load load}, this allows to provide a
        # document to clients that is restored from a persistent store like
        # Redis or also an ActiveRecord model.
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

        # Produce a canonical key for this channel and its parameters. This
        # allows us to create unique documents for separate use cases. e.g. an
        # Issue is the document scope, but has multiple fields that are
        # synchronized, the title, description, labels, …
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

        def channel_identifier
          return ["test", identifier] if Rails.env.test?

          JSON.parse(identifier)
        end

        def handle_initiate
          self.class.initiate_handler.each do |handler|
            method(handler).call
          end

          nil
        end

        def handle_receive(request = {})
          self.class.receive_handler
              .each_with_object(request) do |handler, req|
            method(handler).call(req)
          end

          nil
        end

        def handle_sync(request = {})
          self.class.sync_handler
              .each_with_object(request) do |handler, req|
            method(handler).call(req)
          end

          nil
        end

        def handle_transmit(request = {})
          self.class.transmit_handler
              .each_with_object(request) do |handler, req|
            method(handler).call(req)
          end

          nil
        end
      end
    end
  end
end
