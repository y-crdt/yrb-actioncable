# frozen_string_literal: true

module Helpers
  CONFIG = { url: "redis://127.0.0.1:6379/1" }.freeze

  def redis
    @redis ||= ::Redis.new(CONFIG)
  end

  def with_clean_redis
    redis.disconnect!
    redis.flushall
    begin
      yield
    ensure
      redis.flushall
      redis.quit
    end
  end
end
