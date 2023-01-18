# frozen_string_literal: true

module Y
  module Lib0
    class TypedArray < ::Array
      # @overload initialize()
      #   Initialize a TypedArray of size=0
      # @overload initialize(size)
      #   Initialize a TypedArray of given size and initialize with 0's
      #   @param size [Integer]
      # @overload initialize(typed_array)
      #   Create a new TypedArray from an existing
      # @overload initialize(buffer)
      #   Create a new TypedArray from a buffer. All elements must be valid
      #   integers that fit into a single byte (unsigned int). This is not
      #   checked at runtime.
      # @overload initialize(buffer, offset)
      #   Create a new TypedArray from a buffer and offset. The projected
      # @overload initialize(buffer, offset, size)
      def initialize(*args) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        if args.size.zero?
          super()
        elsif args.size == 1 && args.first.is_a?(Numeric)
          super(args.first, 0)
        elsif args.size == 1 && args.first.is_a?(TypedArray)
          super(args.first)
        elsif args.size == 1 && args.first.is_a?(Enumerable)
          super(args.first.to_a)
        elsif args.size == 2 && args.first.is_a?(Enumerable) && args.last.is_a?(Numeric)
          super(args.first.to_a[(args.last)..-1])
        elsif args.size == 3 && args.first.is_a?(Enumerable) && args[1].is_a?(Numeric) && args.last.is_a?(Numeric)
          super(args.first.to_a[args[1], args.last])
        else
          raise "invalid arguments: [#{args.join(", ")}"
        end
      end

      def replace_with(array, offset = 0)
        array.each_with_index do |element, index|
          self[offset + index] = element
        end
      end
    end
  end
end
