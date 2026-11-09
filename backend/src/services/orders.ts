import { type Db, rows } from '../db/pool.js';
import { iso } from '../util.js';

export const OPEN_BILL_STATUSES = ['new', 'accepted', 'preparing', 'ready'] as const;

interface BillRow {
  stall_order_id: number;
  order_id: number;
  stall_id: number;
  canteen_id: number;
  stall_name: string;
  bill_date: Date | null;
  bill_no: string | null;
  subtotal: number;
  tax: number;
  total: number;
  status: string;
  pickup_code: string | null;
  code_attempts: number;
  code_locked_until: Date | null;
  estimated_ready_at: Date | null;
  accepted_at: Date | null;
  preparing_at: Date | null;
  ready_at: Date | null;
  collected_at: Date | null;
  cancelled_at: Date | null;
  expired_at: Date | null;
  cancel_reason: string | null;
  created_at: Date;
  user_id: number;
  student_name: string;
  order_status: string;
}

interface ItemRow {
  item_id: number;
  stall_order_id: number;
  product_id: number;
  product_name: string;
  price: number;
  gst_rate: number;
  qty_requested: number;
  quantity: number;
  item_status: string;
}

const dateOnly = (d: Date | null) => (d ? d.toISOString().slice(0, 10) : null);

/** The pickup code is shown once the bill is paid (OTP workflow guide: student and vendor both see it). */
const codeVisible = (status: string) => (OPEN_BILL_STATUSES as readonly string[]).includes(status) || status === 'collected';

function serializeBill(b: BillRow, items: ItemRow[]) {
  return {
    id: String(b.stall_order_id),
    orderId: String(b.order_id),
    stallId: String(b.stall_id),
    stallName: b.stall_name,
    canteenId: String(b.canteen_id),
    billNo: b.bill_no,
    billDate: dateOnly(b.bill_date),
    status: b.status,
    pickupCode: codeVisible(b.status) ? b.pickup_code : null,
    codeLocked: Boolean(b.code_locked_until && b.code_locked_until.getTime() > Date.now()),
    studentFirstName: b.student_name.split(' ')[0],
    subtotal: b.subtotal,
    tax: b.tax,
    total: b.total,
    items: items
      .filter((i) => i.stall_order_id === b.stall_order_id)
      .map((i) => ({
        id: String(i.item_id),
        productId: String(i.product_id),
        name: i.product_name,
        price: i.price,
        gstRate: i.gst_rate,
        qtyRequested: i.qty_requested,
        quantity: i.quantity,
        status: i.item_status,
      })),
    createdAt: iso(b.created_at),
    estimatedReadyAt: iso(b.estimated_ready_at),
    acceptedAt: iso(b.accepted_at),
    preparingAt: iso(b.preparing_at),
    readyAt: iso(b.ready_at),
    collectedAt: iso(b.collected_at),
    cancelledAt: iso(b.cancelled_at),
    expiredAt: iso(b.expired_at),
    cancelReason: b.cancel_reason,
  };
}

export type BillView = ReturnType<typeof serializeBill> & { userId: string };

const BILL_SELECT = `
  SELECT so.*, s.stall_name, o.user_id, o.status AS order_status, u.name AS student_name
    FROM stall_orders so
    JOIN stalls s ON s.stall_id = so.stall_id
    JOIN orders o ON o.order_id = so.order_id
    JOIN users u ON u.user_id = o.user_id`;

async function itemsFor(db: Db, billIds: number[]) {
  if (!billIds.length) return [];
  return rows<ItemRow>(db, 'SELECT * FROM order_items WHERE stall_order_id IN (?) ORDER BY item_id', [billIds]);
}

/** Loads bills by a WHERE clause on `so` / `o`, with their items. */
export async function loadBills(db: Db, where: string, params: unknown[], orderBy = 'so.stall_order_id'): Promise<BillView[]> {
  const bills = await rows<BillRow>(db, `${BILL_SELECT} WHERE ${where} ORDER BY ${orderBy}`, params);
  const items = await itemsFor(db, bills.map((b) => b.stall_order_id));
  return bills.map((b) => ({ ...serializeBill(b, items), userId: String(b.user_id) }));
}

interface OrderRow {
  order_id: number;
  user_id: number;
  canteen_id: number;
  canteen_name: string;
  subtotal: number;
  tax: number;
  convenience_fee: number;
  total: number;
  status: string;
  gateway_order_ref: string | null;
  payment_expires_at: Date;
  created_at: Date;
  paid_at: Date | null;
}

/** Loads full orders (header + bills + items), newest first. */
export async function loadOrders(db: Db, where: string, params: unknown[], limit = 50) {
  const orders = await rows<OrderRow>(
    db,
    `SELECT o.*, c.canteen_name FROM orders o JOIN canteens c ON c.canteen_id = o.canteen_id
      WHERE ${where} ORDER BY o.order_id DESC LIMIT ${Math.max(1, Math.min(limit, 200))}`,
    params,
  );
  if (!orders.length) return [];
  const bills = await loadBills(db, 'so.order_id IN (?)', [orders.map((o) => o.order_id)]);
  return orders.map((o) => ({
    id: String(o.order_id),
    userId: String(o.user_id),
    canteenId: String(o.canteen_id),
    canteenName: o.canteen_name,
    status: o.status,
    subtotal: o.subtotal,
    tax: o.tax,
    convenienceFee: o.convenience_fee,
    total: o.total,
    gatewayOrderRef: o.gateway_order_ref,
    paymentExpiresAt: iso(o.payment_expires_at),
    createdAt: iso(o.created_at),
    paidAt: iso(o.paid_at),
    bills: bills.filter((b) => b.orderId === String(o.order_id)).map(({ userId: _u, ...b }) => b),
  }));
}

export type OrderView = Awaited<ReturnType<typeof loadOrders>>[number];

export async function loadOrder(db: Db, orderId: number) {
  return (await loadOrders(db, 'o.order_id = ?', [orderId], 1))[0];
}
