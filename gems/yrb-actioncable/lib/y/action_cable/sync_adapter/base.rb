# frozen_string_literal: true

module Y
  module ActionCable
    module SyncAdapter
      class Base
        def add(key, value, offset = 0)
          raise NotImplementedError
        end

        # Append value to stream and return entry ID
        #
        # @param [String] key
        # @param [Hash] value
        # @return [String] The entry ID
        def append(key, value)
          raise NotImplementedError
        end

        # Remove value for key
        #
        # @param [String] key
        # @param [String] value
        def remove(key, value)
          raise NotImplementedError
        end

        # Remove all keys that exceed a TTL threshold.
        #
        # We assume that clients that have fallen behind by the given threshold,
        # can be evicted (soft-evict). In cases where every client has fallen
        # behind, the delta does not make too much sense, we have to evict based
        # on an absolute threshold (current timestamp - max_absolute_threshold).
        #
        # @param [String] key
        # @param [Integer] threshold
        # @param [Integer] max_absolute_threshold
        def remove_all(key, threshold: 30.seconds,
                       max_absolute_threshold: 30.minutes)
          raise NotImplementedError
        end

        # Move item by setting offset
        #
        # @param [String] key
        # @param [String] value
        # @param [Numeric] offset
        def move(key, value, offset)
          raise NotImplementedError
        end

        # Return the minimum value in the stream identified by key
        #
        # @param [String] key
        # @return [Integer]
        def min(key)
          raise NotImplementedError
        end

        # Return the maximum value in the stream identified by key
        #
        # @param [String] key
        # @return [Integer]
        def max(key)
          raise NotImplementedError
        end

        # Read values from stream starting (inclusive) from offset
        #
        # @param [String] key
        # @param [String] offset
        # @return [::Array<Object>]
        def read(key, offset = nil)
          raise NotImplementedError
        end

        # Truncate the stream up until the given offset
        #
        # @param [String] key
        # @param [String] offset
        def truncate(key, offset)
          raise NotImplementedError
        end
      end
    end
  end
end
