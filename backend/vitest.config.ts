import { defineConfig } from 'vitest/config';

// Integration tests run against the real MySQL + Redis from docker-compose, using a separate test database.
export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 60_000,
    env: {
      NODE_ENV: 'test',
      DB_NAME: 'brunchy_test',
      REDIS_URL: 'redis://127.0.0.1:6379/1',
      JWT_ACCESS_SECRET: 'test-access-secret-0123456789abcdef',
      MOCK_GATEWAY_SECRET: 'test-mock-gateway-secret-0123456789',
      OTP_DEV_ECHO: 'true',
      IGNORE_CANTEEN_HOURS: 'true',
      JOBS_ENABLED: 'false',
      RATE_LIMIT_ENABLED: 'false',
      LOG_LEVEL: 'silent',
    },
  },
});
