# frozen_string_literal: true

module Y
  module Sync
    MESSAGE_YJS_SYNC_STEP_1 = 0
    MESSAGE_YJS_SYNC_STEP_2 = 1
    MESSAGE_YJS_UPDATE = 2

    # @param [Y::Lib0::Encoding::Encoder] encoder
    # @param [Y::Doc] doc
    def self.write_sync_step1(encoder, doc)
      Y::Lib0::Encoding.write_var_uint(encoder, MESSAGE_YJS_SYNC_STEP_1)
      state_vector = doc.state
      Y::Lib0::Encoding.write_var_uint8_array(encoder, state_vector)
    end

    # @param [Y::Lib0::Encoding::Encoder] encoder
    # @param [Y::Doc] doc
    # @param [Array<Integer>] encoded_state_vector
    def self.write_sync_step2(encoder, doc, encoded_state_vector)
      Y::Lib0::Encoding.write_var_uint(encoder, MESSAGE_YJS_SYNC_STEP_2)
      Y::Lib0::Encoding.write_var_uint8_array(encoder, doc.diff(encoded_state_vector))
    end

    # @param [Y::Lib0::Decoding::Decoder] decoder
    # @param [Y::Lib0::Encoding::Encoder] encoder
    # @param [Y::Doc] doc
    def self.read_sync_step1(decoder, encoder, doc)
      write_sync_step2(encoder, doc, Y::Lib0::Decoding.read_var_uint8_array(decoder))
    end

    # @param [Y::Lib0::Decoding::Decoder] decoder
    # @param [Y::Doc] doc
    # @param [Object] transaction_origin
    # TODO: y-rb sync does not support transaction origins
    def self.read_sync_step2(decoder, doc, _transaction_origin)
      update = Y::Lib0::Decoding.read_var_uint8_array(decoder)
      doc.sync(update)
    end

    # @param [Y::Lib0::Encoding::Encoder] encoder
    # @param [Array<Integer>] update
    def self.write_update(encoder, update)
      Y::Lib0::Encoding.write_var_uint(encoder, MESSAGE_YJS_UPDATE)
      Y::Lib0::Encoding.write_var_uint8_array(encoder, update)
    end

    # @param [Y::Lib0::Decoding::Decoder] decoder
    # @param [Y::Doc] doc
    # @param [Object] transaction_origin
    def self.read_update(decoder, doc, _transaction_origin)
      read_sync_step2(decoder, doc, _transaction_origin)
    end

    # @param [Y::Lib0::Decoding::Decoder] decoder
    # @param [Y::Lib0::Encoding::Encoder] encoder
    # @param [Y::Doc] doc
    # @param [Object] transaction_origin
    # TODO: y-rb sync does not support transaction origins
    def self.read_sync_message(decoder, encoder, doc, transaction_origin)
      message_type = Y::Lib0::Decoding.read_var_uint(decoder)

      case message_type
      when MESSAGE_YJS_SYNC_STEP_1
        read_sync_step1(decoder, encoder, doc)
      when MESSAGE_YJS_SYNC_STEP_2
        read_sync_step2(decoder, doc, transaction_origin)
      when MESSAGE_YJS_UPDATE
        read_update(decoder, doc, transaction_origin)
      else
        raise "unknown message type"
      end

      message_type
    end
  end
end
