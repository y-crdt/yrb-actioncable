# frozen_string_literal: true

module Y
  module Actioncable
    module Adapter
      # A local Y::Actioncable coordinator for reliable messaging.
      class Test
        # @attr_reader [Hash] store
        attr_reader :store

        def initialize
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
        def append(key, value)
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

        # Move item by setting offset
        #
        # @param [String] key
        # @param [String] value
        # @param [Numeric] offset
        def move(key, value, offset)
          store[key] ||= {}
          store[key][value] = offset if store[key][value] && offset > store[key][value]

          nil
        end

        # Read values from stream starting (inclusive) from offset
        #
        # @param [String] key
        # @param [String, nil] offset
        # @return [::Array<Object>]
        def read(key, offset = nil)
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
