import type { Server as HttpServer } from 'node:http';
import { Server } from 'socket.io';
import { pool } from './db/pool.js';
import { logger } from './logger.js';
import { verifyAccessToken } from './middleware/auth.js';
import { loadBills, loadOrder } from './services/orders.js';

/**
 * Live updates (build guide: push instead of polling).
 * Connect with socket.io-client: io(url, { auth: { token: accessToken } }).
 * Rooms: every user joins `user:{id}`; vendors also join `stall:{stallId}`.
 * Events:
 *   bill.new      (vendor)   a newly paid bill for this stall
 *   bill.updated  (vendor + student)  a bill changed status
 *   order.updated (student)  the order changed (paid, expired)
 */
let io: Server | null = null;

export function attachRealtime(server: HttpServer) {
  io = new Server(server, { cors: { origin: '*' } });
  io.use((socket, next) => {
    try {
      socket.data.user = verifyAccessToken(String(socket.handshake.auth?.token ?? ''));
      next();
    } catch {
      next(new Error('UNAUTHORIZED'));
    }
  });
  io.on('connection', (socket) => {
    const user = socket.data.user;
    socket.join(`user:${user.id}`);
    if (user.role === 'vendor' && user.stallId) socket.join(`stall:${user.stallId}`);
  });
  return io;
}

export function closeRealtime() {
  io?.close();
  io = null;
}

/** Sends the latest state of these bills to their stall and their student. Call after the transaction commits. */
export async function publishBills(billIds: number[], event: 'bill.new' | 'bill.updated') {
  if (!io || !billIds.length) return;
  try {
    const bills = await loadBills(pool, 'so.stall_order_id IN (?)', [billIds]);
    for (const { userId, ...bill } of bills) {
      io.to(`stall:${bill.stallId}`).emit(event, bill);
      io.to(`user:${userId}`).emit('bill.updated', bill);
    }
  } catch (err) {
    logger.error({ err }, 'publishBills failed');
  }
}

export async function publishOrder(orderId: number) {
  if (!io) return;
  try {
    const order = await loadOrder(pool, orderId);
    if (order) io.to(`user:${order.userId}`).emit('order.updated', order);
  } catch (err) {
    logger.error({ err }, 'publishOrder failed');
  }
}
