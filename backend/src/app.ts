import path from 'node:path';
import cors from 'cors';
import express from 'express';
import { config, isProduction } from './config.js';
import { pool } from './db/pool.js';
import { errorHandler, notFound } from './errors.js';
import { redis } from './redis.js';
import { adminRouter } from './routes/admin/index.js';
import { authRouter } from './routes/auth.js';
import { canteensRouter } from './routes/canteens.js';
import { checkoutRouter } from './routes/checkout.js';
import { ordersRouter } from './routes/orders.js';
import { paymentsRouter } from './routes/payments.js';
import { vendorRouter } from './routes/vendor.js';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1); // behind Nginx in production
  // The apps send a bearer token, so any origin may call the API. Only the admin panel's own origins may send its
  // refresh cookie (credentials); every other origin gets the plain "*" answer, which browsers never pair with cookies.
  const adminCors = cors({ origin: true, credentials: true });
  const openCors = cors();
  app.use((req, res, next) => {
    const origin = String(req.headers.origin ?? '').replace(/\/$/, '');
    return (origin && config.ADMIN_ORIGINS.includes(origin) ? adminCors : openCors)(req, res, next);
  });

  // The webhook needs the raw body for its signature, so payments are mounted before the JSON parser.
  app.use('/api/v1', paymentsRouter);
  app.use(express.json({ limit: '100kb' }));

  app.get('/api/v1/health', async (_req, res) => {
    await pool.query('SELECT 1');
    await redis.ping();
    res.json({ status: 'ok', time: new Date().toISOString() });
  });

  // Photos uploaded from the admin panel. In production Caddy serves this folder; locally the API does.
  if (!isProduction) app.use('/uploads', express.static(path.resolve(config.UPLOADS_DIR), { maxAge: '1d' }));

  app.use('/api/v1', authRouter, canteensRouter, checkoutRouter, ordersRouter, vendorRouter, adminRouter);

  app.use((_req, _res) => {
    throw notFound('NOT_FOUND', 'No such endpoint');
  });
  app.use(errorHandler);
  return app;
}
