# frozen_string_literal: true

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
REDIS = Redis.new(url: redis_url)
