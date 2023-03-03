# frozen_string_literal: true

module Y
  module ActionCable
    module SyncAdapter
      # A local Y::ActionCable coordinator for reliable messaging.
      class Test < Base
        # @attr_reader [Hash] store
        attr_reader :store

        MAX_INTEGER = ((2**((0.size * 8) - 2)) - 1)
        private_constant :MAX_INTEGER

        def initialize
          super()

          @store = {}
          @last_ts = 0
          @counter = 0
        end

        # @param [String] key
        # @param [String] value
        # @param [Numeric] offset
        def add(key, value, offset = 0)
          store[key] ||= {}
          store[key][value] = offset

          nil
        end

        # Append value to stream and return entry ID
        #
        # @param [String] key
        # @param [Hash] value
        # @return [String] The entry ID
        def append(key, value) # rubocop:disable Metrics/MethodLength
          curr_ts = Time.current.to_i
          if curr_ts == @last_ts
            @counter += 1
          else
            @counter = 0
          end
          @last_ts = curr_ts

          entry_id = "#{Time.current.to_i}-#{@counter}"

          store[key] ||= []
          store[key] << [entry_id, value]

          entry_id
        end

        # Return the minimum value in the stream identified by key
        #
        # @param [String] key
        # @return [Numeric]
        def min(key)
          store[key] ||= {}
          result = store[key].sort_by { |_k, v| -v }

          return 0 unless result
          return 0 unless result.size.positive?

          result.first[1].to_i
        end

        # Return the maximum value in the stream identified by key
        #
        # @param [String] key
        # @return [Integer]
        def max(key)
          store[key] ||= {}
          result = store[key].sort_by { |_k, v| v }

          return MAX_INTEGER unless result
          return MAX_INTEGER unless result.size.positive?

          result.first[1].to_i
        end

        # Move item by setting offset
        #
        # @param [String] key
        # @param [String] value
        # @param [Numeric] offset
        def move(key, value, offset)
          store[key] ||= {}
          if store[key][value] && offset > store[key][value]
            store[key][value] =
              offset
          end

          nil
        end

        # Read values from stream starting (inclusive) from offset
        #
        # @param [String] key
        # @param [String, nil] offset
        # @return [::Array<Object>]
        def read(key, offset = nil) # rubocop:disable Metrics/CyclomaticComplexity
          offset ||= "0-0"

          store[key] ||= {}
          store[key].filter do |(entry_id, _)|
            ts1, counter1 = entry_id.split("-").map(&:to_i)
            ts2, counter2 = offset.split("-").map(&:to_i)

            gte = false
            gte = true if ts1 >= ts2

            gte = counter1 >= counter2 if ts1 == ts2

            gte
          end
        end

        # @param [String] key
        # @param [String] value
        def remove(key, value)
          store[key] ||= {}
          store[key].delete(value)

          nil
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
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def remove_all(key, threshold: 30.seconds,
                       max_absolute_threshold: 30.minutes)
          # remove all clients that have exceeded the max_absolute_threshold
          virtual_current_id = Time.current.to_i * 1000 * 1000
          virtual_min_id = virtual_current_id - (max_absolute_threshold.to_i * 1000 * 1000)

          store[key] ||= {}
          store[key] = store[key].filter do |_, v|
            v >= virtual_min_id
          end

          # remove all clients that have exceeded the relative threshold
          max_id = max(key)
          soft_limit = max_id - (threshold.to_i * 1000 * 1000)

          store[key] ||= {}
          store[key] = store[key].filter do |_, v|
            v >= soft_limit
          end

          nil
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        # Truncate the stream up until the given offset (exclusive)
        #
        # [1, 2, 3].truncate(2) = [2, 3]
        #
        # @param [String] key
        # @param [String] offset
        def truncate(key, offset)
          store[key] ||= {}
          store[key].filter! do |(entry_id, _)|
            ts1, counter1 = entry_id.split("-").map(&:to_i)
            ts2, counter2 = offset.split("-").map(&:to_i)

            gte = false
            gte = true if ts1 >= ts2

            gte = counter1 >= counter2 if ts1 == ts2

            gte
          end

          nil
        end
      end
    end
  end
end
