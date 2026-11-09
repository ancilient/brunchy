import { Router } from 'express';
import { pool } from '../db/pool.js';
import { badRequest, notFound } from '../errors.js';
import { currentUser, requireAuth, requireRole } from '../middleware/auth.js';
import { cancelBillByStudent } from '../services/bills.js';
import { loadOrders } from '../services/orders.js';
import { parseId } from '../util.js';

export const ordersRouter = Router();
ordersRouter.use(['/orders', '/bills'], requireAuth, requireRole('student'));

/** The student's orders, newest first, each with its bills and live status. */
ordersRouter.get('/orders', async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 20, 100);
  res.json({ orders: await loadOrders(pool, 'o.user_id = ?', [currentUser(req).id], limit) });
});

ordersRouter.get('/orders/:id', async (req, res) => {
  const id = parseId(req.params.id);
  if (!id) throw badRequest('INVALID_ID', 'Invalid order id');
  const [order] = await loadOrders(pool, 'o.order_id = ? AND o.user_id = ?', [id, currentUser(req).id], 1);
  if (!order) throw notFound('ORDER_NOT_FOUND', 'Order not found');
  res.json({ order, serverTime: new Date().toISOString() });
});

ordersRouter.post('/bills/:billId/cancel', async (req, res) => {
  const id = parseId(req.params.billId);
  if (!id) throw badRequest('INVALID_ID', 'Invalid bill id');
  res.json(await cancelBillByStudent(currentUser(req), id));
});
