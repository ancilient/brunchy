import type { Request, RequestHandler } from 'express';
import { config } from '../config.js';
import { AppError } from '../errors.js';
import { redis } from '../redis.js';

/**
 * Counts one hit for `key` in a fixed window stored in Redis (so it holds across API instances) and throws 429 once
 * the limit is passed. Usable inside a service when the key is only known after some work (e.g. the Google account).
 */
export async function hitRateLimit(name: string, limit: number, windowSeconds: number, key: string) {
  if (!config.RATE_LIMIT_ENABLED) return;
  const redisKey = `rl:${name}:${key}:${Math.floor(Date.now() / 1000 / windowSeconds)}`;
  const count = await redis.incr(redisKey);
  if (count === 1) await redis.expire(redisKey, windowSeconds);
  if (count > limit) throw new AppError(429, 'TOO_MANY_REQUESTS', 'Too many requests. Please wait a moment and try again.');
}

/** Fixed-window rate limit as middleware. Stops button mashing and abuse (build guide: rate-limit each user). */
export function rateLimit(name: string, limit: number, windowSeconds: number, key: (req: Request) => string): RequestHandler {
  return async (req, _res, next) => {
    await hitRateLimit(name, limit, windowSeconds, key(req));
    next();
  };
}

export const byUser = (req: Request) => String(req.user?.id ?? req.ip);
export const byIp = (req: Request) => String(req.ip);
