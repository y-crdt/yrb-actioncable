# frozen_string_literal: true

module Y
  module Lib0
    module Buffer
      def self.create_uint8_array_view_from_buffer(enumerable, offset, size)
        TypedArray.new(enumerable, offset, size)
      end
    end
  end
end
