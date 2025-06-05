require 'redis'
require 'redis/namespace'
require 'connection_pool'

redis_config = {
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
  timeout: 1,
  reconnect_attempts: 2,
  driver: :hiredis
}

# Create a connection pool for Redis
REDIS_POOL = ConnectionPool.new(size: 5, timeout: 5) do
  Redis::Namespace.new(
    "org_chart_#{Rails.env}",
    redis: Redis.new(redis_config)
  )
end

# Configure Redis for cache store
Rails.application.config.cache_store = :redis_cache_store, {
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
  namespace: "org_chart_cache_#{Rails.env}",
  connect_timeout: 30,
  read_timeout: 0.2,
  write_timeout: 0.2,
  reconnect_attempts: 1,
  error_handler: -> (method:, returning:, exception:) {
    Rails.logger.error(
      "Redis error: #{exception.class}: #{exception.message}\n" \
      "Method: #{method}, Returning: #{returning}"
    )
  }
} 