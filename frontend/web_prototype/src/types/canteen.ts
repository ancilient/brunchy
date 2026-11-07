/**
 * Types according to Brunchy Canteen Platform Flow & Blueprint v3.1
 */

export type UserRole = 'student' | 'vendor' | 'manager' | 'admin';

export type CanteenStatus = 'open' | 'closed';

export type StallStatus = 'open' | 'paused' | 'closed';

export type ApprovalStatus = 'draft' | 'pending' | 'published' | 'rejected';

export type OrderStatus = 'pending' | 'paid' | 'cancelled' | 'expired';

export type BillStatus = 
  | 'awaiting_payment'
  | 'waiting_for_acceptance'
  | 'new'
  | 'accepted'
  | 'preparing'
  | 'ready'
  | 'completed'
  | 'collected'
  | 'rejected'
  | 'cancelled'
  | 'expired'
  | 'refunded';

export type QRState = 'locked' | 'active' | 'grace' | 'expired' | 'used';

export type PickupSlot = 'now' | '15_min_break' | '1_hour_break';

export type RefundReasonCode = 
  | 'OUT_OF_STOCK'
  | 'ITEM_UNAVAILABLE'
  | 'KITCHEN_ISSUE'
  | 'STALL_EMERGENCY'
  | 'STALL_REJECTED'
  | 'CANCELLED_BY_USER'
  | 'PAYMENT_TIMEOUT'
  | 'LATE_PAYMENT'
  | 'DUPLICATE_PAYMENT';

export type RefundStatus = 
  | 'requested'
  | 'approved'
  | 'processing'
  | 'completed'
  | 'failed'
  | 'rejected';

export interface Canteen {
  canteen_id: number;
  canteen_name: string;
  opening_time: string; // e.g. "07:30"
  closing_time: string; // e.g. "18:00"
  status: CanteenStatus;
  requires_approval: boolean;
  last_order_minutes: number;
  latitude: number;
  longitude: number;
  distance_meters: number;
  is_active: boolean;
}

export interface Stall {
  stall_id: number;
  canteen_id: number;
  stall_name: string;
  bill_prefix: string;
  gst_rate: number;
  status: StallStatus;
  paused_until: string | null;
  is_active: boolean;
  category: string;
  accent_color: string;
  icon_name: string;
  avg_prep_time_mins: number;
}

export interface Product {
  product_id: number;
  stall_id: number;
  canteen_id: number;
  product_name: string;
  category: string;
  price: number;
  stock_quantity: number;
  daily_default_qty: number;
  prep_minutes: number;
  image_url: string;
  is_veg: boolean;
  approval_status: ApprovalStatus;
  rejection_reason?: string;
  is_active: boolean;
  created_by?: number;
  approved_by?: number;
  approved_at?: string;
  description?: string;
}

export interface DailyMenuItem {
  menu_date: string;
  product_id: number;
  added_by: number;
  created_at: string;
}

export interface PriceChangeRequest {
  request_id: number;
  product_id: number;
  product_name: string;
  stall_name: string;
  canteen_id: number;
  old_price: number;
  new_price: number;
  reason: string;
  requested_by: number;
  status: 'pending' | 'approved' | 'rejected';
  decided_by?: number;
  decided_at?: string;
  decision_note?: string;
  created_at: string;
}

export interface CartItem {
  product: Product;
  quantity: number;
  stall: Stall;
}

export interface OrderItemSnapshot {
  item_id: number;
  stall_order_id: number;
  product_id: number;
  product_name: string;
  price: number;
  gst_rate: number;
  qty_requested: number;
  quantity: number;
  item_status: 'active' | 'unavailable_refunded';
  refund_id?: number;
}

export interface StallBill {
  stall_order_id: number;
  order_id: number;
  stall_id: number;
  canteen_id: number;
  stall_name: string;
  bill_prefix: string;
  bill_date: string;
  bill_no: string; // e.g. "BH-0117"
  pickup_code: string; // 3-digit code e.g. "345" per Brunchy flow
  subtotal: number;
  tax: number;
  total: number;
  status: BillStatus;
  qr_token: string;
  qr_token_hash: string;
  items: OrderItemSnapshot[];
  created_at: string;
  accepted_at?: string;
  preparing_at?: string;
  ready_at?: string;
  estimated_time_mins: number;
  estimated_ready_time?: string;
  qr_active_until?: string;
  qr_grace_until?: string;
  collected_at?: string;
  collected_by?: string;
  expired_at?: string;
  cancelled_at?: string;
  cancel_reason?: string;
  reopen_count: number;
  is_blurred_sealed: boolean;
}

export interface Order {
  order_id: number;
  user_id: number;
  user_name: string;
  user_phone: string;
  canteen_id: number;
  canteen_name: string;
  idempotency_key: string;
  subtotal: number;
  tax: number;
  convenience_fee: number; // e.g. ₹5
  total: number;
  pickup_slot: PickupSlot;
  status: OrderStatus;
  gateway_order_ref: string;
  payment_expires_at: string;
  created_at: string;
  paid_at?: string;
  bills: StallBill[];
}

export interface Refund {
  refund_id: number;
  stall_order_id: number;
  item_id?: number | null;
  payment_id: number;
  amount: number;
  destination: 'original' | 'wallet';
  reason_code: RefundReasonCode;
  requested_by?: number | null;
  approved_by?: number | null;
  gateway_refund_ref: string;
  status: RefundStatus;
  created_at: string;
  completed_at?: string;
  stall_name?: string;
  bill_no?: string;
  details?: string;
}

export interface AuditLogEntry {
  audit_id: number;
  actor_name: string;
  role: UserRole;
  action: string;
  table_name: string;
  record_id: number;
  old_value: Record<string, any>;
  new_value: Record<string, any>;
  created_at: string;
}

export interface VendorLedgerEntry {
  ledger_id: number;
  canteen_id: number;
  stall_id: number;
  stall_name: string;
  stall_order_id: number;
  bill_no: string;
  gross_amount: number;
  gateway_fee: number;
  refund_amount: number;
  net_amount: number;
  status: 'pending' | 'settled';
  created_at: string;
  settled_at?: string;
}

export interface UserProfile {
  user_id: number;
  name: string;
  email: string;
  phone: string;
  register_no: string;
  role: UserRole;
  canteen_id?: number;
  stall_id?: number;
  no_show_count: number;
  ordering_paused_until: string | null;
  is_logged_in: boolean;
}
