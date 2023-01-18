# frozen_string_literal: true

module Y
  module Lib0
    module Decoding
      class Decoder
        attr_accessor :arr, :pos

        def initialize(uint8_array)
          @arr = uint8_array
          @pos = 0
        end
      end

      def self.create_decoder(uint8_array)
        Decoder.new(uint8_array)
      end

      def self.has_content(decoder)
        decoder.pos != decoder.arr.size
      end

      def self.clone(decoder, new_pos = decoder.pos)
        decoder = create_decoder(decoder.arr)
        decoder.pos = new_pos
        decoder
      end

      def self.read_uint8_array(decoder, size)
        view = Buffer.create_uint8_array_view_from_buffer(decoder.arr, decoder.pos + 0, size)
      end

      def self.read_var_uint8_array(decoder)
        read_uint8_array(decoder, read_var_uint(decoder))
      end

      def self.read_var_uint(decoder)
        num = 0
        mult = 1
        size = decoder.arr.size
        while decoder.pos < size
          r = decoder.arr[decoder.pos]
          decoder.pos += 1
          num = num + (r & Binary::BITS7) * mult
          mult *= 128 # next iteration, shift 7 "more" to the left
          if r < Binary::BIT8
            return num
          end
          if num > Integer::MAX
            raise "integer out of range"
          end
        end
        raise "unexpected end of array"
      end

      def self.decode_base64_to_uint8_array(str)
        Base64.strict_decode64(str).unpack("C*")
      end
    end
  end
end
