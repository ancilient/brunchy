import { createServer } from 'node:http';
import { createApp } from './app.js';
import { config } from './config.js';
import { pool } from './db/pool.js';
import { startJobs, stopJobs } from './jobs/holdExpiry.js';
import { logger } from './logger.js';
import { attachRealtime, closeRealtime } from './realtime.js';
import { redis } from './redis.js';

const server = createServer(createApp());
attachRealtime(server);
startJobs();

// 0.0.0.0 so a phone on the same Wi-Fi (or via `adb reverse`) can reach it.
server.listen(config.PORT, '0.0.0.0', () => {
  logger.info(`Brunchy API listening on http://localhost:${config.PORT}/api/v1 (${config.NODE_ENV})`);
});

async function shutdown(signal: string) {
  logger.info(`${signal} received, shutting down`);
  server.close();
  closeRealtime();
  await stopJobs();
  await pool.end();
  redis.disconnect();
  process.exit(0);
}
process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
