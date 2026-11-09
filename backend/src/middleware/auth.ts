import type { NextFunction, Request, RequestHandler, Response } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { forbidden, unauthorized } from '../errors.js';

export type Role = 'student' | 'vendor' | 'manager' | 'admin';

export interface AuthUser {
  id: number;
  role: Role;
  stallId: number | null;
  canteenId: number | null;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

interface AccessClaims {
  sub: string;
  role: Role;
  stallId: number | null;
  canteenId: number | null;
}

export function signAccessToken(user: AuthUser) {
  const claims: AccessClaims = { sub: String(user.id), role: user.role, stallId: user.stallId, canteenId: user.canteenId };
  return jwt.sign(claims, config.JWT_ACCESS_SECRET, { expiresIn: `${config.JWT_ACCESS_MINUTES}m`, issuer: 'brunchy' });
}

export function verifyAccessToken(token: string): AuthUser {
  try {
    const c = jwt.verify(token, config.JWT_ACCESS_SECRET, { issuer: 'brunchy' }) as unknown as AccessClaims;
    return { id: Number(c.sub), role: c.role, stallId: c.stallId ?? null, canteenId: c.canteenId ?? null };
  } catch {
    throw unauthorized('Your session has expired. Please log in again.');
  }
}

/** Requires `Authorization: Bearer <access token>`. */
export const requireAuth: RequestHandler = (req: Request, _res: Response, next: NextFunction) => {
  const header = req.headers.authorization ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) throw unauthorized();
  req.user = verifyAccessToken(token);
  next();
};

/** Only the given roles may call this route. A student can never use vendor actions. */
export const requireRole =
  (...roles: Role[]): RequestHandler =>
  (req, _res, next) => {
    if (!req.user) throw unauthorized();
    if (!roles.includes(req.user.role)) throw forbidden('FORBIDDEN', 'You are not allowed to do this');
    next();
  };

export const currentUser = (req: Request): AuthUser => {
  if (!req.user) throw unauthorized();
  return req.user;
};
