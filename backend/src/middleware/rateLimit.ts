import type { Request, RequestHandler } from 'express';
import { config } from '../config.js';
import { AppError } from '../errors.js';
import { redis } from '../redis.js';

/**
 * Fixed-window rate limit stored in Redis, so it holds across both API instances.
 * Stops button mashing and abuse (build guide: rate-limit each user).
 */
export function rateLimit(name: string, limit: number, windowSeconds: number, key: (req: Request) => string): RequestHandler {
  return async (req, _res, next) => {
    if (!config.RATE_LIMIT_ENABLED) return next();
    const redisKey = `rl:${name}:${key(req)}:${Math.floor(Date.now() / 1000 / windowSeconds)}`;
    const count = await redis.incr(redisKey);
    if (count === 1) await redis.expire(redisKey, windowSeconds);
    if (count > limit) throw new AppError(429, 'TOO_MANY_REQUESTS', 'Too many requests. Please wait a moment and try again.');
    next();
  };
}

export const byUser = (req: Request) => String(req.user?.id ?? req.ip);
export const byIp = (req: Request) => String(req.ip);
