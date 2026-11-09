import { Redis } from 'ioredis';
import { config } from './config.js';

/** Shared Redis client: OTP codes, rate limits, menu cache. */
export const redis = new Redis(config.REDIS_URL, { maxRetriesPerRequest: 3, lazyConnect: false });

/** BullMQ needs its own connections with maxRetriesPerRequest = null. */
export const createQueueConnection = () => new Redis(config.REDIS_URL, { maxRetriesPerRequest: null });
