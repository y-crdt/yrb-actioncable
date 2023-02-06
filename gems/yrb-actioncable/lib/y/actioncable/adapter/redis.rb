# frozen_string_literal: true

module Y
  module Actioncable
    module Adapter
      # A distributed Y::Actioncable coordinator for reliable messaging.
      class Redis
        # @attr_reader [::Redis] client The redis client
        attr_reader :client

        # @param [Hash] config
        def initialize(config)
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
        # @return [String] The entry ID
        def append(key, value)
          client.xadd(key, value)
        end

        # @param [String] key
        # @param [String] value
        def remove(key, value)
          client.zrem(key, value)

          nil
        end

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
        # @return [Numeric]
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

        # Read values from stream starting (inclusive) from offset
        #
        # @param [String] key
        # @param [String] offset
        # @return [::Array<Object>]
        def read(key, offset = nil)
          offset ||= "-"

          result = client.xrange(
            key,
            offset,
            "+"
          )

          return [] unless result
          return [] unless result.size.positive?

          result
        end

        # Truncate the stream up until the given offset
        #
        # @param [String] key
        # @param [String] offset
        def truncate(key, offset)
          client.xtrim(key, offset, strategy: "MINID")

          nil
        end
      end
    end
  end
end
