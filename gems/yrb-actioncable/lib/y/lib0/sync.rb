# frozen_string_literal: true

module Y
  module Lib0
    module Sync
      def self.read_sync_step1(decoder, encoder, doc)
        write_sync_step2(encoder, doc, Decoding.read_var_uint8_array(decoder))
      end

      def self.read_sync_step2(decoder, doc, transaction_origin)
        update = Decoding.read_var_uint8_array(decoder)
        doc.sync(update)
      end
    end
  end
end
