# frozen_string_literal: true

module Y
  module ActionCable
    module Sync
      module Protocol
        extend ActiveSupport::Concern

        MESSAGE_SYNC = 0
        MESSAGE_AWARENESS = 1

        private_constant :MESSAGE_SYNC, :MESSAGE_AWARENESS

        included do
          # handler
          add_initiate_handler :protocol_initiate
          add_transmit_handler :protocol_transmit
        end

        def protocol_initiate
          encoder = Y::Lib0::Encoding.create_encoder
          Y::Lib0::Encoding.write_var_uint(encoder, MESSAGE_SYNC)
          Y::Protocol.write_sync_step1(encoder, doc)
          update = Y::Lib0::Encoding.to_uint8_array(encoder)
          update = Y::Lib0::Encoding.encode_uint8_array_to_base64(update)

          transmit({ op: :update, update: update })
          # TODO: implement awareness
          #   https://github.com/yjs/y-websocket/blob/master/bin/utils.js#L278-L284
        end

        def protocol_transmit(message)
          # integrate updates in the y-rb document
          integrate(message) if message[Field::ACTION] == Op::UPDATE
        end

        private

        # Integrate incoming updates
        #
        # @param [Hash] message The encoded message must include a field named
        #   exactly like the field argument. The field value must be a Base64
        #   binary.
        def integrate(message) # rubocop:disable Metrics/MethodLength
          update = Y::Lib0::Decoding.decode_base64_to_uint8_array(
            message[Field::UPDATE]
          )

          encoder = Y::Lib0::Encoding.create_encoder
          decoder = Y::Lib0::Decoding.create_decoder(update)
          message_type = Y::Lib0::Decoding.read_var_uint(decoder)
          case message_type
          when MESSAGE_SYNC
            Y::Lib0::Encoding.write_var_uint(encoder, MESSAGE_SYNC)
            Y::Protocol.read_sync_message(decoder, encoder, doc, nil)

            # If the `encoder` only contains the type of reply message and no
            # message, there is no need to send the message. When `encoder` only
            # contains the type of reply, its length is 1.
            if Y::Lib0::Encoding.length(encoder) > 1
              update = Y::Lib0::Encoding.to_uint8_array(encoder)
              update = Y::Lib0::Encoding.encode_uint8_array_to_base64(update)

              transmit({ op: :update, update: update })
            end
          when MESSAGE_AWARENESS
            # TODO: implement awareness
            #   https://github.com/yjs/y-websocket/blob/master/bin/utils.js#L179-L181
          else
            raise "unexpected message_type=`#{message_type}`"
          end
        end
      end
    end
  end
end
