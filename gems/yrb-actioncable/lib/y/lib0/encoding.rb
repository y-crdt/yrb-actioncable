# frozen_string_literal: true

module Y
  module Lib0
    module Encoding
      class Encoder
        attr_accessor :bufs, :cpos, :cbuf

        def initialize
          @cpos = 0
          @cbuf = TypedArray.new(100)
          @bufs = []
        end
      end

      def self.create_encoder
        Encoder.new
      end

      def self.length(encoder)
        size = encoder.cpos
        i = 0
        while i < encoder.bufs.size
          size += encoder.bufs[i].size
          i += 1
        end
        size
      end

      def self.to_uint8_array(encoder) # rubocop:disable Metrics/MethodLength
        typed_arr = TypedArray.new(length(encoder))
        cur_pos = 0
        i = 0
        while i < encoder.bufs.size
          d = encoder.bufs[i]
          typed_arr.replace_with(d, cur_pos)
          cur_pos += d.size
          i += 1
        end
        typed_arr.replace_with(
          Buffer.create_uint8_array_view_from_buffer(
            encoder.cbuf,
            0,
            encoder.cpos
          ),
          cur_pos
        )
        typed_arr
      end

      def self.verify_size(encoder, size)
        buffer_size = encoder.cbuf.size

        return unless buffer_size - encoder.cpos < size

        encoder.bufs << Buffer.create_uint8_array_view_from_buffer(encoder.cbuf, 0, encoder.cpos)
        encoder.cbuf = TypedArray.new([buffer_size, size].max * 2)
        encoder.cpos = 0
      end

      def self.write(encoder, num)
        buffer_size = encoder.cbuf.size
        if encoder.cpos == buffer_size
          encoder.bufs << encoder.cbuf
          encoder.cbuf = TypedArray.new(buffer_size * 2)
          encoder.cpos = 0
        end

        encoder.cbuf[encoder.cpos] = num
        encoder.cpos += 1
      end

      def self.set(encoder, pos, num) # rubocop:disable Metrics/MethodLength
        buffer = nil
        i = 0
        while i < encoder.bufs.size && buffer.nil?
          b = encoder.bufs[i]
          if pos < b.size
            buffer = b
          else
            pos -= b.size
          end

          i += 1
        end

        buffer = encoder.cbuf if buffer.nil?
        buffer[pos] = num
      end

      def self.write_uint8(encoder, num)
        write(encoder, num)
      end

      def self.set_uint8(encoder, pos, num)
        set(encoder, pos, num)
      end

      def self.write_var_uint(encoder, num)
        while num > Binary::BITS7
          write(encoder, Binary::BIT8 | (Binary::BITS7 & num))
          num = (num / 128.0).floor # shift >>> 7
        end
        write(encoder, Binary::BITS7 & num)
      end

      def self.write_uint8_array(encoder, uint8_array) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        buffer_size = encoder.cbuf.size
        cpos = encoder.cpos
        left_copy_size = [buffer_size - cpos, uint8_array.size].min
        right_copy_size = uint8_array.size - left_copy_size
        encoder.cbuf.replace_with(uint8_array.slice(0, left_copy_size), cpos)
        encoder.cpos += left_copy_size

        return unless right_copy_size.positive?

        # Still something to write, write right half..
        # Append new buffer
        encoder.bufs.push(encoder.cbuf)
        # must have at least size of remaining buffer
        encoder.cbuf = TypedArray.new([buffer_size * 2, right_copy_size].max)
        # copy array
        encoder.cbuf.replace_with(uint8_array[left_copy_size..])
        encoder.cpos = right_copy_size
      end

      def self.write_var_uint8_array(encoder, uint8_array)
        write_var_uint(encoder, uint8_array.size)
        write_uint8_array(encoder, uint8_array)
      end

      def self.unsigned_right_shift(value, amount)
        mask = (1 << (32 - amount)) - 1
        (value >> amount) & mask
      end

      def self.encode_uint8_array_to_base64(arr)
        Base64.strict_encode64(arr.pack("C*"))
      end
    end
  end
end
