import cors from 'cors';
import express from 'express';
import { pool } from './db/pool.js';
import { errorHandler, notFound } from './errors.js';
import { redis } from './redis.js';
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
  app.use(cors());

  // The webhook needs the raw body for its signature, so payments are mounted before the JSON parser.
  app.use('/api/v1', paymentsRouter);
  app.use(express.json({ limit: '100kb' }));

  app.get('/api/v1/health', async (_req, res) => {
    await pool.query('SELECT 1');
    await redis.ping();
    res.json({ status: 'ok', time: new Date().toISOString() });
  });

  app.use('/api/v1', authRouter, canteensRouter, checkoutRouter, ordersRouter, vendorRouter);

  app.use((_req, _res) => {
    throw notFound('NOT_FOUND', 'No such endpoint');
  });
  app.use(errorHandler);
  return app;
}
