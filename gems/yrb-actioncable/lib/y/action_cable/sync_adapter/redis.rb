# frozen_string_literal: true

module Y
  module ActionCable
    module SyncAdapter
      # A distributed Y::ActionCable coordinator for reliable messaging.
      class Redis < Base
        # @attr_reader [::Redis] client The redis client
        attr_reader :client

        # @param [Hash] config
        def initialize(config)
          super()

          @client = ::Redis.new(url: config[:url])
        end

        # @param [String] key
        # @param [String] value
        # @param [Numeric] offset
        def add(key, value, offset = 0)
          client.zadd(key, offset.to_f, value)

          nil
        end

        # Append value to stream and return entry ID
        #
        # @param [String] key
        # @param [Hash] value
        # @return [Integer] The entry ID
        def append(key, value)
          entry_id = client.xadd(key, value)
          entry_id_to_i(entry_id)
        end

        # Remove key
        #
        # @param [String] key
        # @param [String] value
        def remove(key, value)
          client.zrem(key, value)

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
        # rubocop:disable Metrics/AbcSize
        def remove_all(key, threshold: 30.seconds,
                       max_absolute_threshold: 30.minutes)
          # remove all clients that have exceeded the max_absolute_threshold
          virtual_current_id = Time.current.to_i * 1000 * 1000
          virtual_min_id = virtual_current_id - (max_absolute_threshold.to_i * 1000 * 1000)

          client.zremrangebyscore(key, "-inf", virtual_min_id)

          # remove all clients that have exceeded the relative threshold
          max_id = max(key)
          soft_limit = max_id - (threshold.to_i * 1000 * 1000)

          client.zremrangebyscore(key, "-inf", soft_limit)

          # virtual_current_id      = 1676450680000000
          # virtual_min_id          = 1676449458000000
          # max_absolute_threshold  = 1800000000
          # max_id                  = 4611686018427387903
          # soft_limit              = 4611686018397387903

          nil
        end
        # rubocop:enable Metrics/AbcSize

        # Move item by setting offset
        #
        # @param [String] key
        # @param [String] value
        # @param [Numeric] offset
        def move(key, value, offset)
          client.zadd(
            key,
            offset.to_f,
            value,
            gt: true
          )

          nil
        end

        # Return the minimum value in the stream identified by key
        #
        # @param [String] key
        # @return [Integer]
        def min(key)
          result = client.zrangebyscore(
            key,
            "-inf",
            "+inf",
            with_scores: true,
            limit: [0, 1]
          )

          return 0 unless result
          return 0 unless result.size.positive?

          result.first[1].to_i
        end

        # Return the maximum value in the stream identified by key
        #
        # @param [String] key
        # @return [Integer]
        def max(key)
          result = client.zrange(
            key,
            -1,
            -1,
            with_scores: true
          )

          return Time.current.to_i * 1000 unless result
          return Time.current.to_i * 1000 unless result.size.positive?

          result.first[1].to_i
        end

        # Read values from stream starting (inclusive) from offset
        #
        # @param [String] key
        # @param [Integer] offset
        # @return [::Array<Object>]
        def read(key, offset = nil)
          offset ||= 0
          offset_entry_id = i_to_entry_id(offset)

          result = client.xrange(
            key,
            offset_entry_id,
            "+"
          )

          return [] unless result
          return [] unless result.size.positive?

          result
        end

        # Truncate the stream up until the given offset
        #
        # @param [String] key
        # @param [Integer] offset
        def truncate(key, offset)
          offset_entry_id = i_to_entry_id(offset)
          client.xtrim(key, offset_entry_id, strategy: "MINID")

          nil
        end

        private

        # Converts an entry_id to a 3-zero padded integer
        #
        # @param [String] entry_id
        # @return [Integer]
        def entry_id_to_i(entry_id)
          entry_id
            .split("-")
            .reduce("") { |v, p| v + p.to_s.ljust(3, "0") }
            .to_i
        end

        # Converts a right-side 3-zero padded integer to a valid Redis entry_id
        #
        # @example Correctly padded integer
        #   i = "1234567001"
        #   entry_id = i_to_entry_id(i) # 1234567-001
        #
        # @param [Integer] int The padded integer
        # @return [String]
        def i_to_entry_id(int)
          [int[0..-4], int[-3, 3]].join("-")
        end
      end
    end
  end
end
