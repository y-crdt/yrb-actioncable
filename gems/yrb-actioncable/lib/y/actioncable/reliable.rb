# frozen_string_literal: true

module Y
  module Actioncable
    module Reliable # rubocop:disable Metrics/ModuleLength
      extend ActiveSupport::Concern

      KEY_PREFIX = "reliable_stream"
      STREAM_INACTIVE_TIMEOUT = 1.hour
      USER_INACTIVE_TIMEOUT = 15.minutes
      LAST_ID_FIELD = "last_id"
      CLOCK_FIELD = "clock"

      private_constant(
        :KEY_PREFIX,
        :STREAM_INACTIVE_TIMEOUT,
        :USER_INACTIVE_TIMEOUT,
        :LAST_ID_FIELD
      )

      included do
        unless method_defined? :current_user
          raise "`current_user` is not defined. A ReliableChannel requires " \
                "current_user to be an instance of a `User` model."
        end
      end

      class_methods do
        attr_reader :registered_reliable_actions

        def reliable_broadcast(method) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          method_name = if method.is_a? Symbol
                          method.to_s
                        else
                          method
                        end
          method_sym = method_name.to_sym

          @registered_reliable_actions ||= Set.new
          @registered_reliable_actions.add(method_name)

          # broadcast received data to all clients
          define_method method_sym do |data| # rubocop:disable Metrics/MethodLength
            key = stream_key(method_name)

            # add new entry to stream
            last_id = with_redis do |redis|
              redis.xadd(key, { data: data[:data] })
            end

            # broadcast new entry to all clients
            ActionCable.server.broadcast(
              key,
              {
                last_id: last_id,
                clock: data[CLOCK_FIELD],
                data: data[:data]
              }
            )
          end

          # acknowledge last known ID (by current user)
          define_method "ack_#{method_name}".to_sym do |data|
            key = stream_ack_key(method_name)
            with_redis do |redis|
              score = map_entry_id_to_score(data[LAST_ID_FIELD])
              redis.zadd(key, [score, current_user.id], gt: true)
            end
          end
        end
      end

      # we need to override this method to inject our own callback for subscribe
      # without forcing the user to know about calling super() for #subscribe
      def subscribe_to_channel
        run_callbacks :subscribe do
          reliable_subscribed
        end

        super
      end

      def unsubscribe_from_channel # :nodoc:
        run_callbacks :unsubscribe do
          reliable_unsubscribed
        end

        super
      end

      protected

      def id
        params[:id]
      end

      private

      def reliable_subscribed # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        # reject subscription if there is no ID present
        if id.blank?
          Rails.logger.error("`id` is not present. The parameter :id must be " \
                             "present in order for ReliableChannel to work.")

          reject_subscription
        end

        # create a reliable stream for all registered actions
        self.class.registered_reliable_actions.each do |reliable_action|
          key = stream_key(reliable_action)
          stream_from key
        end

        # create a stream for the current user
        stream_for current_user

        # initialize per-user and per-stream state
        with_redis do |redis|
          redis.pipelined do |pipeline|
            self.class.registered_reliable_actions
                .map do |reliable_action|
              key = stream_ack_key(reliable_action)
              pipeline.zadd(key, [-1, current_user.id])
            end.flatten
          end
        end
      end

      def reliable_unsubscribed
        # remove all user state from registered reliable streams
        with_redis do |redis|
          redis.pipelined do |pipeline|
            self.class.registered_reliable_actions.map do |reliable_action|
              key = stream_ack_key(reliable_action)
              pipeline.zrem(key, current_user.id)
            end
          end
        end
      end

      def user_key
        "user:#{current_user.id}"
      end

      def stream_key(method)
        "#{KEY_PREFIX}:#{method}:#{id}"
      end

      def stream_ack_key(method)
        "#{stream_key(method)}:ack"
      end

      # Trim stream up to the minimum commonly shared entry ID across all
      # registered clients.
      def trim_stream(key, min_id)
        with_redis do |redis|
          redis.xtrim(key, min_id)
        end
      end

      # Maps a Redis stream entry ID to a value that can be used as a score
      # value in a Redis sorted set. The max score value is 2^53
      # (https://redis.io/commands/zadd/). A Unix epoch represented in ms, and
      # calculated in 2022 is around 2^40. If we pad the counter by a max value
      # of 2^10, we can safely store values up to the year 2248 (2^43).
      #
      # This allows us to store up to a max of 999 concurrent messages for a
      # given ID, within a given channel, within the same millisecond. The
      # method will raise if the counter part of the entry_id exceeds the limit.
      def map_entry_id_to_score(entry_id)
        ts, c = entry_id.split("-")
        if c.to_i > 999
          raise "concurrent message counter exceeds 99 and cannot be " \
                "concat with the timestamp"
        end
        # pad counter, this allows up to 9999 concurrent messages within the
        # same ms
        c.rjust(3, "0")
        "#{ts}#{c}".to_i
      end

      # Reverse the mapping done in Reliable#map_entry_id_to_score
      def map_score_to_entry_id(score)
        score = score.to_s
        c_padded, ts = score.slice!(-3..), score # rubocop:disable Style/ParallelAssignment
        "#{ts}-#{c_padded.to_i}"
      end

      # Provide access to a Redis client
      #
      # @return [Redis] The Redis client
      def with_redis(&block)
        raise "no block given" if block.blank?

        Y::Actioncable.configuration.redis.call(block)
      end
    end
  end
end
