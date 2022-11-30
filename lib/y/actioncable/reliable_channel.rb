# frozen_string_literal: true

module Y
  module Actioncable
    module ReliableChannel
      extend ActiveSupport::Concern

      KEY_PREFIX = "reliable_stream"
      STREAM_INACTIVE_TIMEOUT = 1.hour
      USER_INACTIVE_TIMEOUT = 15.minutes

      private_constant :KEY_PREFIX, :STREAM_TTL

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
          define_method method_sym do |data|
            key = stream_key(method_name)

            # add new entry to stream
            last_id = with_redis do |redis|
              redis.xadd(key, { data: data[:data] })
            end

            # broadcast new entry to all clients
            ActionCable.server.broadcast(key, { last_id: last_id, data: data[:data] })
          end

          # acknowledge last known ID (bu current user)
          define_method "ack_#{method_name}".to_sym do |data|
            key = stream_key(method_name)
            with_redis do |redis|
              redis.hset(user_key, key, data["last_id"])
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
              key = "#{stream_key(reliable_action)}:session"

              pipeline.zadd(key, [current_user.id, -1])
            end.flatten
          end
        end
      end

      def reliable_unsubscribed
        # remove all user state from registered reliable streams
        with_redis do |redis|
          redis.pipelined do |pipeline|
            self.class.registered_reliable_actions.map do |reliable_action|
              key = "#{stream_key(reliable_action)}:session"
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
