import React, { createContext, useContext, useState, useEffect, useRef } from 'react';
import {
  Canteen,
  Stall,
  Product,
  Order,
  StallBill,
  CartItem,
  UserRole,
  PriceChangeRequest,
  Refund,
  AuditLogEntry,
  VendorLedgerEntry,
  UserProfile,
  QRState,
  StallStatus,
  PickupSlot
} from '../types/canteen';
import {
  INITIAL_CANTEENS,
  INITIAL_STALLS,
  INITIAL_PRODUCTS,
  INITIAL_ORDERS,
  INITIAL_PRICE_REQUESTS,
  INITIAL_AUDIT_LOG,
  INITIAL_LEDGER,
} from '../data/mockData';

interface StockShortageItem {
  product: Product;
  requested: number;
  available: number;
}

interface CanteenContextType {
  // Roles & View
  currentRole: UserRole;
  setCurrentRole: (role: UserRole) => void;
  selectedCanteenId: number;
  setSelectedCanteenId: (id: number) => void;
  selectedVendorStallId: number;
  setSelectedVendorStallId: (id: number) => void;
  currentUser: UserProfile;
  completeStudentLogin: (name: string, phone: string, regNo?: string) => void;
  logoutStudent: () => void;

  // Demo Clock Speed Multiplier
  demoClockMultiplier: 1 | 10 | 30;
  setDemoClockMultiplier: (mult: 1 | 10 | 30) => void;

  // Master Data
  canteens: Canteen[];
  stalls: Stall[];
  products: Product[];
  orders: Order[];
  priceRequests: PriceChangeRequest[];
  refunds: Refund[];
  auditLogs: AuditLogEntry[];
  ledger: VendorLedgerEntry[];

  // Cart & Checkout
  cart: CartItem[];
  addToCart: (product: Product, quantity?: number) => { success: boolean; reason?: string };
  updateCartQuantity: (productId: number, delta: number) => void;
  removeFromCart: (productId: number) => void;
  clearCart: () => void;
  cartCanteen: Canteen | undefined;
  pickupSlot: PickupSlot;
  setPickupSlot: (slot: PickupSlot) => void;
  convenienceFee: number;
  
  // Checkout & Holds
  stockShortages: StockShortageItem[];
  clearShortages: () => void;
  handleShortageChoice: (productId: number, takeAvailable: boolean) => void;
  isHoldActive: boolean;
  holdSecondsLeft: number;
  activePendingOrder: Order | null;
  holdExpiredCount: number;
  startCheckout: () => { success: boolean; shortage?: boolean; message?: string };
  completeUpiPayment: (paymentMethod: string) => Promise<{ success: boolean; orderId?: number }>;
  cancelCheckoutHold: () => void;

  // Student Actions & Status
  cancelStudentBill: (stallOrderId: number) => void;
  getStudentBills: () => StallBill[];
  hasActiveOrder: boolean;

  // Vendor Actions
  vendorAcceptOrder: (stallOrderId: number, prepMins?: number) => void;
  vendorRejectOrder: (stallOrderId: number, reason?: string) => void;
  markBillReady: (stallOrderId: number) => void;
  vendorCompleteByCode: (code: string) => { success: boolean; message: string; bill?: StallBill };
  markItemUnavailable: (stallOrderId: number, itemId: number) => void;
  reopenExpiredBill: (stallOrderId: number) => { success: boolean; message: string };
  validateAndScanQr: (token: string, stallId: number) => {
    status: 'valid' | 'late' | 'expired' | 'used' | 'not_ready' | 'wrong_stall' | 'invalid';
    bill?: StallBill;
    message: string;
  };
  handOverBill: (stallOrderId: number) => void;
  updateProductStock: (productId: number, newStock: number) => void;
  toggleProductActive: (productId: number) => void;
  resetDailyStock: (stallId: number) => void;
  proposeNewItem: (item: Partial<Product>) => void;
  requestPriceChange: (productId: number, newPrice: number, reason: string) => void;
  setStallStatus: (stallId: number, status: StallStatus, pauseMinutes?: number, emergencyReason?: string) => void;
  vendorAlertCount: number;
  clearVendorAlert: () => void;

  // Manager Actions
  approveProduct: (productId: number) => void;
  rejectProduct: (productId: number, reason: string) => void;
  hideProduct: (productId: number) => void;
  approvePriceRequest: (requestId: number) => void;
  rejectPriceRequest: (requestId: number, reason: string) => void;
  copyYesterdaysMenu: (canteenId: number) => void;
  toggleRequireApproval: (canteenId: number) => void;
  approveRefund: (refundId: number) => void;
  updateCanteenSettings: (canteenId: number, updates: Partial<Canteen>) => void;

  // Helpers
  calculateQrState: (bill: StallBill) => { state: QRState; secondsLeft: number; label: string };
  getLiveBusyLevel: (canteenId: number) => 'Low' | 'Medium' | 'High';
}

const CanteenContext = createContext<CanteenContextType | undefined>(undefined);

// Everything the student would lose if Android closes the app in the background (it often does while the
// UPI app is open) is kept in localStorage. Bump the key when the shape of this data changes.
const STATE_KEY = 'brunchy_state_v1';
const USER_KEY = 'brunchy_user';
const DEMO_PHONE = '9845012345';            // the seeded demo student (user_id 1) owns the sample order

type SavedState = {
  orders: Order[]; refunds: Refund[]; products: Product[]; cart: CartItem[];
  selectedCanteenId: number; pickupSlot: PickupSlot; nextCodeSeed: number;
};

function loadSavedState(): Partial<SavedState> {
  try {
    const raw = localStorage.getItem(STATE_KEY);
    if (!raw) return {};
    const s = JSON.parse(raw) as Partial<SavedState>;
    if (!Array.isArray(s.orders) || !Array.isArray(s.products)) return {};
    // A checkout that was waiting for payment when the app closed can never complete: release its stock.
    const stale = s.orders.filter((o) => o.status === 'pending');
    if (stale.length) {
      s.orders = s.orders.map((o) => (o.status === 'pending' ? { ...o, status: 'expired' as const } : o));
      s.products = s.products.map((p) => {
        const held = stale.flatMap((o) => o.bills).flatMap((b) => b.items).filter((it) => it.product_id === p.product_id);
        return held.length ? { ...p, stock_quantity: p.stock_quantity + held.reduce((n, it) => n + it.quantity, 0) } : p;
      });
    }
    return s;
  } catch {
    return {};
  }
}

const userIdForPhone = (phone: string) => {
  const digits = phone.replace(/\D/g, '');
  return digits === DEMO_PHONE ? 1 : Number(digits.slice(-10)) || Date.now();
};

export const CanteenProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [saved] = useState(loadSavedState);
  const [currentRole, setCurrentRole] = useState<UserRole>('student');
  const [selectedCanteenId, setSelectedCanteenId] = useState<number>(saved.selectedCanteenId ?? 1);
  const [selectedVendorStallId, setSelectedVendorStallId] = useState<number>(1);
  const [demoClockMultiplier, setDemoClockMultiplier] = useState<1 | 10 | 30>(1);

  const [currentUser, setCurrentUser] = useState<UserProfile>(() => {
    const stored = localStorage.getItem(USER_KEY);
    if (stored) {
      try {
        return JSON.parse(stored);
      } catch (e) {
        // fallback
      }
    }
    return {
      user_id: 1,
      name: 'Priya R.',
      email: 'priya.r@university.edu',
      phone: '9845012345',
      register_no: 'ENG2024-8842',
      role: 'student',
      no_show_count: 0,
      ordering_paused_until: null,
      is_logged_in: true,
    };
  });

  const [canteens, setCanteens] = useState<Canteen[]>(INITIAL_CANTEENS);
  const [stalls, setStalls] = useState<Stall[]>(INITIAL_STALLS);
  const [products, setProducts] = useState<Product[]>(saved.products ?? INITIAL_PRODUCTS);
  const [orders, setOrders] = useState<Order[]>(saved.orders ?? INITIAL_ORDERS);
  const [priceRequests, setPriceRequests] = useState<PriceChangeRequest[]>(INITIAL_PRICE_REQUESTS);
  const [refunds, setRefunds] = useState<Refund[]>(saved.refunds ?? []);
  const [auditLogs, setAuditLogs] = useState<AuditLogEntry[]>(INITIAL_AUDIT_LOG);
  const [ledger, setLedger] = useState<VendorLedgerEntry[]>(INITIAL_LEDGER);

  const [cart, setCartState] = useState<CartItem[]>(saved.cart ?? []);
  // cartRef always holds the newest cart, so several addToCart calls in a row (Reorder) all see each other.
  const cartRef = useRef<CartItem[]>(cart);
  const setCart = (next: CartItem[] | ((prev: CartItem[]) => CartItem[])) => {
    const value = typeof next === 'function' ? next(cartRef.current) : next;
    cartRef.current = value;
    setCartState(value);
  };
  const [pickupSlot, setPickupSlot] = useState<PickupSlot>(saved.pickupSlot ?? 'now');
  const convenienceFee = 5; // Flat ₹5 per order

  const [stockShortages, setStockShortages] = useState<StockShortageItem[]>([]);
  const [activePendingOrder, setActivePendingOrder] = useState<Order | null>(null);
  const [holdSecondsLeft, setHoldSecondsLeft] = useState<number>(300);
  const [isHoldActive, setIsHoldActive] = useState<boolean>(false);
  const [holdExpiredCount, setHoldExpiredCount] = useState<number>(0);
  const [vendorAlertCount, setVendorAlertCount] = useState<number>(0);

  // 3-digit daily running code counter
  const [nextCodeSeed, setNextCodeSeed] = useState<number>(saved.nextCodeSeed ?? 346);

  const generateNext3DigitCode = () => {
    const code = nextCodeSeed;
    setNextCodeSeed((prev) => (prev >= 999 ? 100 : prev + 1));
    return String(code).padStart(3, '0');
  };

  useEffect(() => {
    const state: SavedState = { orders, refunds, products, cart, selectedCanteenId, pickupSlot, nextCodeSeed };
    try {
      localStorage.setItem(STATE_KEY, JSON.stringify(state));
    } catch {
      // storage full or blocked: the app keeps working, it just won't remember across restarts
    }
  }, [orders, refunds, products, cart, selectedCanteenId, pickupSlot, nextCodeSeed]);

  const completeStudentLogin = (name: string, phone: string, regNo?: string) => {
    const user: UserProfile = {
      user_id: userIdForPhone(phone),
      name: name || 'Student',
      email: `${name.toLowerCase().replace(/\s+/g, '')}@campus.edu`,
      phone: phone || '9876543210',
      register_no: regNo || 'CAMPUS-2026',
      role: 'student',
      no_show_count: 0,
      ordering_paused_until: null,
      is_logged_in: true,
    };
    setCurrentUser(user);
    localStorage.setItem(USER_KEY, JSON.stringify(user));
  };

  const logoutStudent = () => {
    const unlogged = { ...currentUser, is_logged_in: false };
    setCurrentUser(unlogged);
    setCart([]);
    // Remember the signed-out state; removing the key would sign the demo student back in on restart.
    localStorage.setItem(USER_KEY, JSON.stringify(unlogged));
  };

  // Check if student has an active order (Waiting for acceptance, Accepted, Preparing, or Ready)
  const hasActiveOrder = orders.some(
    (o) =>
      o.status === 'paid' &&
      o.user_id === currentUser.user_id &&
      o.bills.some(
        (b) =>
          b.status === 'waiting_for_acceptance' ||
          b.status === 'accepted' ||
          b.status === 'preparing' ||
          b.status === 'ready'
      )
  );

  // Hold timer countdown influenced by demoClockMultiplier
  useEffect(() => {
    let timer: NodeJS.Timeout;
    if (isHoldActive && holdSecondsLeft > 0) {
      const intervalMs = Math.max(100, Math.floor(1000 / demoClockMultiplier));
      timer = setInterval(() => {
        setHoldSecondsLeft((prev) => {
          if (prev <= 1) {
            setIsHoldActive(false);
            setHoldExpiredCount((n) => n + 1);
            if (activePendingOrder) {
              setOrders((ords) =>
                ords.map((o) =>
                  o.order_id === activePendingOrder.order_id ? { ...o, status: 'expired' } : o
                )
              );
              setProducts((prods) =>
                prods.map((p) => {
                  const heldItem = activePendingOrder.bills
                    .flatMap((b) => b.items)
                    .find((it) => it.product_id === p.product_id);
                  if (heldItem) {
                    return { ...p, stock_quantity: p.stock_quantity + heldItem.quantity };
                  }
                  return p;
                })
              );
            }
            setActivePendingOrder(null);
            return 0;
          }
          return prev - 1;
        });
      }, intervalMs);
    }
    return () => clearInterval(timer);
  }, [isHoldActive, holdSecondsLeft, activePendingOrder, demoClockMultiplier]);

  const cartCanteen = canteens.find((c) => c.canteen_id === selectedCanteenId);

  const logAudit = (action: string, table: string, recordId: number, oldValue: any, newValue: any) => {
    const newEntry: AuditLogEntry = {
      audit_id: Date.now(),
      actor_name:
        currentRole === 'student'
          ? currentUser.name
          : currentRole === 'vendor'
          ? `Vendor (Stall #${selectedVendorStallId})`
          : 'Canteen Manager',
      role: currentRole,
      action,
      table_name: table,
      record_id: recordId,
      old_value: oldValue,
      new_value: newValue,
      created_at: new Date().toISOString(),
    };
    setAuditLogs((prev) => [newEntry, ...prev]);
  };

  // Cart operations
  const addToCart = (product: Product, quantity = 1): { success: boolean; reason?: string } => {
    const canteen = canteens.find((c) => c.canteen_id === product.canteen_id);
    if (!canteen || canteen.status !== 'open') {
      return { success: false, reason: 'This canteen is currently closed.' };
    }

    const stall = stalls.find((s) => s.stall_id === product.stall_id);
    if (!stall || stall.status !== 'open') {
      return { success: false, reason: `${stall?.stall_name || 'Stall'} is currently ${stall?.status || 'closed'}.` };
    }

    const cart = cartRef.current;
    if (cart.length > 0 && cart[0].product.canteen_id !== product.canteen_id) {
      return {
        success: false,
        reason: 'One cart equals one canteen. Please clear your current cart to order from another canteen.',
      };
    }

    if (product.stock_quantity <= 0) {
      return { success: false, reason: 'This item is sold out.' };
    }

    const existingIndex = cart.findIndex((item) => item.product.product_id === product.product_id);
    if (existingIndex > -1) {
      const currentQty = cart[existingIndex].quantity;
      if (currentQty + quantity > product.stock_quantity) {
        return { success: false, reason: `Only ${product.stock_quantity} available in stock.` };
      }
      const updated = [...cart];
      updated[existingIndex] = { ...updated[existingIndex], quantity: currentQty + quantity };
      setCart(updated);
    } else {
      setCart([...cart, { product, quantity, stall }]);
    }

    return { success: true };
  };

  const updateCartQuantity = (productId: number, delta: number) => {
    setCart((prev) => {
      const idx = prev.findIndex((item) => item.product.product_id === productId);
      if (idx === -1) return prev;
      const target = prev[idx];
      const newQty = target.quantity + delta;
      if (newQty <= 0) {
        return prev.filter((item) => item.product.product_id !== productId);
      }
      const liveProd = products.find((p) => p.product_id === productId);
      if (liveProd && newQty > liveProd.stock_quantity) {
        return prev;
      }
      const updated = [...prev];
      updated[idx] = { ...target, quantity: newQty };
      return updated;
    });
  };

  const removeFromCart = (productId: number) => {
    setCart((prev) => prev.filter((item) => item.product.product_id !== productId));
  };

  const clearCart = () => setCart([]);

  const startCheckout = () => {
    if (cart.length === 0) return { success: false, message: 'Cart is empty' };

    for (const item of cart) {
      const stall = stalls.find((s) => s.stall_id === item.product.stall_id);
      if (!stall || stall.status !== 'open') {
        return {
          success: false,
          message: `${item.stall.stall_name} is currently ${stall?.status || 'closed'}. Please remove their items.`,
        };
      }
    }

    const shortages: StockShortageItem[] = [];
    for (const item of cart) {
      const liveProd = products.find((p) => p.product_id === item.product.product_id);
      const avail = liveProd ? liveProd.stock_quantity : 0;
      if (item.quantity > avail) {
        shortages.push({
          product: item.product,
          requested: item.quantity,
          available: avail,
        });
      }
    }

    if (shortages.length > 0) {
      setStockShortages(shortages);
      return { success: false, shortage: true };
    }

    const orderId = Date.now();
    const canteenId = cart[0].product.canteen_id;
    const canteen = canteens.find((c) => c.canteen_id === canteenId)!;

    const stallMap: Record<number, CartItem[]> = {};
    cart.forEach((cItem) => {
      if (!stallMap[cItem.stall.stall_id]) stallMap[cItem.stall.stall_id] = [];
      stallMap[cItem.stall.stall_id].push(cItem);
    });

    const bills: StallBill[] = Object.keys(stallMap).map((stallIdStr) => {
      const stallId = Number(stallIdStr);
      const items = stallMap[stallId];
      const stall = stalls.find((s) => s.stall_id === stallId)!;
      const subtotal = items.reduce((sum, it) => sum + it.product.price * it.quantity, 0);
      const tax = Number(((subtotal * stall.gst_rate) / 100).toFixed(2));
      const total = Number((subtotal + tax).toFixed(2));
      const stallOrderId = orderId + stallId;

      return {
        stall_order_id: stallOrderId,
        order_id: orderId,
        stall_id: stallId,
        canteen_id: canteenId,
        stall_name: stall.stall_name,
        bill_prefix: stall.bill_prefix,
        bill_date: new Date().toISOString().split('T')[0],
        bill_no: '',
        pickup_code: '', // Assigned once accepted!
        subtotal,
        tax,
        total,
        status: 'awaiting_payment',
        estimated_time_mins: stall.avg_prep_time_mins || 5,
        qr_token: '',
        qr_token_hash: '',
        reopen_count: 0,
        is_blurred_sealed: false,
        created_at: new Date().toISOString(),
        items: items.map((it, idx) => ({
          item_id: stallOrderId * 10 + idx,
          stall_order_id: stallOrderId,
          product_id: it.product.product_id,
          product_name: it.product.product_name,
          price: it.product.price,
          gst_rate: stall.gst_rate,
          qty_requested: it.quantity,
          quantity: it.quantity,
          item_status: 'active',
        })),
      };
    });

    const orderSubtotal = bills.reduce((sum, b) => sum + b.subtotal, 0);
    const orderTax = Number(bills.reduce((sum, b) => sum + b.tax, 0).toFixed(2));
    const orderTotal = Number((orderSubtotal + orderTax + convenienceFee).toFixed(2));

    const newOrder: Order = {
      order_id: orderId,
      user_id: currentUser.user_id,
      user_name: currentUser.name,
      user_phone: currentUser.phone,
      canteen_id: canteenId,
      canteen_name: canteen.canteen_name,
      idempotency_key: `idem_${orderId}`,
      subtotal: orderSubtotal,
      tax: orderTax,
      convenience_fee: convenienceFee,
      total: orderTotal,
      pickup_slot: pickupSlot,
      status: 'pending',
      gateway_order_ref: `order_gw_${orderId}`,
      payment_expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
      created_at: new Date().toISOString(),
      bills,
    };

    setProducts((prev) =>
      prev.map((p) => {
        const cartItem = cart.find((c) => c.product.product_id === p.product_id);
        if (cartItem) {
          return { ...p, stock_quantity: Math.max(0, p.stock_quantity - cartItem.quantity) };
        }
        return p;
      })
    );

    setActivePendingOrder(newOrder);
    setOrders((prev) => [newOrder, ...prev]);
    setIsHoldActive(true);
    setHoldSecondsLeft(300);

    return { success: true };
  };

  const handleShortageChoice = (productId: number, takeAvailable: boolean) => {
    const shortage = stockShortages.find((s) => s.product.product_id === productId);
    if (!shortage) return;

    if (takeAvailable && shortage.available > 0) {
      setCart((prev) =>
        prev.map((item) =>
          item.product.product_id === productId ? { ...item, quantity: shortage.available } : item
        )
      );
    } else {
      setCart((prev) => prev.filter((item) => item.product.product_id !== productId));
    }

    setStockShortages((prev) => prev.filter((s) => s.product.product_id !== productId));
  };

  const clearShortages = () => setStockShortages([]);

  const cancelCheckoutHold = () => {
    if (activePendingOrder) {
      setProducts((prods) =>
        prods.map((p) => {
          const heldItem = activePendingOrder.bills
            .flatMap((b) => b.items)
            .find((it) => it.product_id === p.product_id);
          if (heldItem) {
            return { ...p, stock_quantity: p.stock_quantity + heldItem.quantity };
          }
          return p;
        })
      );
      setOrders((prev) =>
        prev.map((o) => (o.order_id === activePendingOrder.order_id ? { ...o, status: 'cancelled' } : o))
      );
    }
    setIsHoldActive(false);
    setActivePendingOrder(null);
  };

  // Complete Payment via webhook simulation -> creates bills in "waiting_for_acceptance" per PDF flow!
  const completeUpiPayment = async (paymentMethod: string): Promise<{ success: boolean; orderId?: number }> => {
    if (!activePendingOrder) return { success: false };

    // Simulate network delay
    await new Promise((resolve) => setTimeout(resolve, 800));

    const confirmedBills: StallBill[] = [];

    activePendingOrder.bills.forEach((bill, idx) => {
      const billNo = `${bill.bill_prefix}-${Math.floor(100 + Math.random() * 900)}`;
      const token = `QR_${bill.bill_prefix}_${Date.now()}_${idx}`;

      confirmedBills.push({
        ...bill,
        bill_no: billNo,
        status: 'waiting_for_acceptance', // Flow: First the order shows waiting for acceptance!
        qr_token: token,
        qr_token_hash: `hash_${token}`,
        created_at: new Date().toISOString(),
      });
    });

    const paidOrder: Order = {
      ...activePendingOrder,
      status: 'paid',
      paid_at: new Date().toISOString(),
      bills: confirmedBills,
    };

    setOrders((prev) => prev.map((o) => (o.order_id === activePendingOrder.order_id ? paidOrder : o)));

    // Clear cart and hold
    setCart([]);
    setIsHoldActive(false);
    setActivePendingOrder(null);
    setVendorAlertCount((prev) => prev + 1);

    return { success: true, orderId: paidOrder.order_id };
  };

  // Vendor accepts order: assigns the 3-digit code (e.g. 345) and estimated time!
  const vendorAcceptOrder = (stallOrderId: number, prepMins?: number) => {
    const code = generateNext3DigitCode();
    const now = new Date();
    const mins = prepMins || 6;
    const estReady = new Date(now.getTime() + mins * 60000).toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
    });

    setOrders((prev) =>
      prev.map((ord) => ({
        ...ord,
        bills: ord.bills.map((b) =>
          b.stall_order_id === stallOrderId
            ? {
                ...b,
                status: 'accepted',
                pickup_code: code,
                accepted_at: now.toISOString(),
                estimated_time_mins: mins,
                estimated_ready_time: estReady,
              }
            : b
        ),
      }))
    );

    logAudit('ACCEPT_ORDER', 'stall_orders', stallOrderId, { status: 'waiting_for_acceptance' }, { status: 'accepted', pickup_code: code, estimated_time_mins: mins });
  };

  // Vendor rejects order -> automatic full refund per PDF
  const vendorRejectOrder = (stallOrderId: number, reason?: string) => {
    setOrders((prev) =>
      prev.map((ord) => {
        const bill = ord.bills.find((b) => b.stall_order_id === stallOrderId);
        if (!bill) return ord;

        const updatedBills = ord.bills.map((b) =>
          b.stall_order_id === stallOrderId
            ? { ...b, status: 'rejected' as const, cancelled_at: new Date().toISOString(), cancel_reason: reason || 'Vendor unavailable' }
            : b
        );

        const newRefund: Refund = {
          refund_id: Date.now(),
          stall_order_id: stallOrderId,
          payment_id: ord.order_id,
          amount: bill.total,
          destination: 'original',
          reason_code: 'STALL_REJECTED',
          gateway_refund_ref: `rfnd_${Date.now()}`,
          status: 'completed',
          created_at: new Date().toISOString(),
          stall_name: bill.stall_name,
          bill_no: bill.bill_no,
          details: `Automatic full refund for ${bill.stall_name} order: ${reason || 'Stall rejected'}.`,
        };
        setRefunds((rf) => [newRefund, ...rf]);

        // Restore stock
        setProducts((prods) =>
          prods.map((p) => {
            const item = bill.items.find((it) => it.product_id === p.product_id);
            if (item) {
              return { ...p, stock_quantity: p.stock_quantity + item.quantity };
            }
            return p;
          })
        );

        return { ...ord, bills: updatedBills };
      })
    );
  };

  // Mark bill ready -> ready state
  const markBillReady = (stallOrderId: number) => {
    const now = new Date();
    const activeUntil = new Date(now.getTime() + 5 * 60 * 1000);
    const graceUntil = new Date(now.getTime() + 8 * 60 * 1000);

    setOrders((prev) =>
      prev.map((ord) => ({
        ...ord,
        bills: ord.bills.map((b) =>
          b.stall_order_id === stallOrderId
            ? {
                ...b,
                status: 'ready',
                ready_at: now.toISOString(),
                qr_active_until: activeUntil.toISOString(),
                qr_grace_until: graceUntil.toISOString(),
              }
            : b
        ),
      }))
    );
    logAudit('MARK_READY', 'stall_orders', stallOrderId, { status: 'accepted' }, { status: 'ready' });
  };

  // Vendor types the 3-digit code at the counter -> marks completed and turns bill blurred/sealed!
  const vendorCompleteByCode = (code: string): { success: boolean; message: string; bill?: StallBill } => {
    const trimmed = code.trim();
    if (!trimmed) return { success: false, message: 'Please enter a 3-digit code.' };

    let foundBill: StallBill | undefined;

    setOrders((prev) =>
      prev.map((ord) => {
        const match = ord.bills.find(
          (b) =>
            (b.pickup_code === trimmed || b.bill_no.toLowerCase().includes(trimmed.toLowerCase())) &&
            (b.status === 'accepted' || b.status === 'ready' || b.status === 'preparing')
        );

        if (match) {
          foundBill = match;
          const updatedBills = ord.bills.map((b) =>
            b.stall_order_id === match.stall_order_id
              ? {
                  ...b,
                  status: 'completed' as const,
                  is_blurred_sealed: true,
                  collected_at: new Date().toISOString(),
                  collected_by: 'Counter Staff',
                }
              : b
          );
          return { ...ord, bills: updatedBills };
        }
        return ord;
      })
    );

    if (foundBill) {
      logAudit('COMPLETE_BY_CODE', 'stall_orders', foundBill.stall_order_id, { status: foundBill.status }, { status: 'completed', is_blurred_sealed: true });
      return {
        success: true,
        message: `Code ${trimmed} verified! Order ${foundBill.bill_no} marked Completed & Sealed.`,
        bill: foundBill,
      };
    }

    return {
      success: false,
      message: `Code ${trimmed} not found among active orders for this stall.`,
    };
  };

  const cancelStudentBill = (stallOrderId: number) => {
    setOrders((prev) =>
      prev.map((ord) => {
        const bill = ord.bills.find((b) => b.stall_order_id === stallOrderId);
        if (!bill) return ord;
        if (bill.status !== 'waiting_for_acceptance' && bill.status !== 'accepted' && bill.status !== 'new') return ord;

        const updatedBills = ord.bills.map((b) =>
          b.stall_order_id === stallOrderId
            ? { ...b, status: 'refunded' as const, cancelled_at: new Date().toISOString(), cancel_reason: 'Student cancelled' }
            : b
        );

        const newRefund: Refund = {
          refund_id: Date.now(),
          stall_order_id: stallOrderId,
          payment_id: ord.order_id,
          amount: bill.total,
          destination: 'original',
          reason_code: 'CANCELLED_BY_USER',
          gateway_refund_ref: `rfnd_${Date.now()}`,
          status: 'completed',
          created_at: new Date().toISOString(),
          stall_name: bill.stall_name,
          bill_no: bill.bill_no,
          details: `Full refund for bill ${bill.bill_no || 'order'} upon student cancellation.`,
        };
        setRefunds((rf) => [newRefund, ...rf]);

        setProducts((prods) =>
          prods.map((p) => {
            const item = bill.items.find((it) => it.product_id === p.product_id);
            if (item) {
              return { ...p, stock_quantity: p.stock_quantity + item.quantity };
            }
            return p;
          })
        );

        return { ...ord, bills: updatedBills };
      })
    );
  };

  const getStudentBills = (): StallBill[] => {
    return orders
      .filter((o) => o.status === 'paid' && o.user_id === currentUser.user_id)
      .flatMap((o) => o.bills)
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
  };

  const markItemUnavailable = (stallOrderId: number, itemId: number) => {
    setOrders((prev) =>
      prev.map((ord) => {
        const bill = ord.bills.find((b) => b.stall_order_id === stallOrderId);
        if (!bill) return ord;
        const targetItem = bill.items.find((it) => it.item_id === itemId);
        if (!targetItem || targetItem.item_status === 'unavailable_refunded') return ord;

        const refundAmt = Number((targetItem.price * targetItem.quantity * (1 + targetItem.gst_rate / 100)).toFixed(2));

        const updatedItems = bill.items.map((it) =>
          it.item_id === itemId ? { ...it, item_status: 'unavailable_refunded' as const } : it
        );

        const newSubtotal = bill.subtotal - targetItem.price * targetItem.quantity;
        const newTax = Number(((newSubtotal * targetItem.gst_rate) / 100).toFixed(2));
        const newTotal = Number((newSubtotal + newTax).toFixed(2));

        const newRefund: Refund = {
          refund_id: Date.now(),
          stall_order_id: stallOrderId,
          item_id: itemId,
          payment_id: ord.order_id,
          amount: refundAmt,
          destination: 'original',
          reason_code: 'ITEM_UNAVAILABLE',
          gateway_refund_ref: `rfnd_${Date.now()}`,
          status: 'completed',
          created_at: new Date().toISOString(),
          stall_name: bill.stall_name,
          bill_no: bill.bill_no,
          details: `Item unavailable (${targetItem.product_name} x ${targetItem.quantity}). Partial refund processed.`,
        };
        setRefunds((rf) => [newRefund, ...rf]);

        return {
          ...ord,
          bills: ord.bills.map((b) =>
            b.stall_order_id === stallOrderId
              ? { ...b, items: updatedItems, subtotal: newSubtotal, tax: newTax, total: newTotal }
              : b
          ),
        };
      })
    );
  };

  const reopenExpiredBill = (stallOrderId: number): { success: boolean; message: string } => {
    let result = { success: false, message: 'Bill not found' };

    setOrders((prev) =>
      prev.map((ord) => {
        const bill = ord.bills.find((b) => b.stall_order_id === stallOrderId);
        if (!bill) return ord;
        if (bill.reopen_count >= 1) {
          result = { success: false, message: 'Vendor QR Reopen allowed only once per bill.' };
          return ord;
        }

        const now = new Date();
        const newGraceUntil = new Date(now.getTime() + 3 * 60 * 1000);

        result = { success: true, message: 'Bill reopened successfully! Student has 3 minutes to collect.' };

        return {
          ...ord,
          bills: ord.bills.map((b) =>
            b.stall_order_id === stallOrderId
              ? {
                  ...b,
                  status: 'ready',
                  qr_grace_until: newGraceUntil.toISOString(),
                  reopen_count: b.reopen_count + 1,
                }
              : b
          ),
        };
      })
    );

    return result;
  };

  const calculateQrState = (bill: StallBill): { state: QRState; secondsLeft: number; label: string } => {
    if (bill.status === 'completed' || bill.status === 'collected' || bill.is_blurred_sealed) {
      return { state: 'used', secondsLeft: 0, label: 'Order Completed' };
    }
    if (bill.status === 'awaiting_payment' || bill.status === 'waiting_for_acceptance' || bill.status === 'new' || bill.status === 'accepted' || bill.status === 'preparing') {
      return { state: 'locked', secondsLeft: 0, label: 'Works when the order is Ready' };
    }
    if (bill.status === 'expired') {
      return { state: 'expired', secondsLeft: 0, label: 'Order Expired' };
    }
    if (bill.status === 'ready' && bill.qr_active_until && bill.qr_grace_until) {
      const now = Date.now();
      const activeTime = new Date(bill.qr_active_until).getTime();
      const graceTime = new Date(bill.qr_grace_until).getTime();

      if (now < activeTime) {
        const sec = Math.max(0, Math.floor((activeTime - now) / 1000));
        return { state: 'active', secondsLeft: sec, label: 'Active - Ready for pickup' };
      } else if (now < graceTime) {
        const sec = Math.max(0, Math.floor((graceTime - now) / 1000));
        return { state: 'grace', secondsLeft: sec, label: 'Grace Period - Marked late' };
      } else {
        return { state: 'expired', secondsLeft: 0, label: 'Order Expired' };
      }
    }
    return { state: 'locked', secondsLeft: 0, label: 'Locked' };
  };

  const validateAndScanQr = (
    token: string,
    stallId: number
  ): {
    status: 'valid' | 'late' | 'expired' | 'used' | 'not_ready' | 'wrong_stall' | 'invalid';
    bill?: StallBill;
    message: string;
  } => {
    let targetBill: StallBill | undefined;
    for (const ord of orders) {
      const match = ord.bills.find(
        (b) =>
          b.qr_token === token ||
          b.bill_no.toLowerCase() === token.toLowerCase().trim() ||
          b.pickup_code === token.trim()
      );
      if (match) {
        targetBill = match;
        break;
      }
    }

    if (!targetBill) {
      return { status: 'invalid', message: 'Invalid or unrecognized code/QR token.' };
    }

    if (targetBill.stall_id !== stallId) {
      const thisStall = stalls.find((s) => s.stall_id === stallId);
      return {
        status: 'wrong_stall',
        bill: targetBill,
        message: `Wrong stall! This bill belongs to ${targetBill.stall_name}, not ${thisStall?.stall_name}.`,
      };
    }

    if (targetBill.status === 'completed' || targetBill.status === 'collected' || targetBill.is_blurred_sealed) {
      return {
        status: 'used',
        bill: targetBill,
        message: `ALREADY COLLECTED & SEALED at ${targetBill.collected_at ? new Date(targetBill.collected_at).toLocaleTimeString() : 'earlier'}. Cannot be used again.`,
      };
    }

    if (targetBill.status === 'waiting_for_acceptance') {
      return {
        status: 'not_ready',
        bill: targetBill,
        message: 'Order waiting for kitchen acceptance.',
      };
    }

    return {
      status: 'valid',
      bill: targetBill,
      message: `VALID 3-DIGIT CODE (${targetBill.pickup_code}). Verified for counter hand over.`,
    };
  };

  const handOverBill = (stallOrderId: number) => {
    setOrders((prev) =>
      prev.map((ord) => ({
        ...ord,
        bills: ord.bills.map((b) =>
          b.stall_order_id === stallOrderId
            ? {
                ...b,
                status: 'completed',
                is_blurred_sealed: true,
                collected_at: new Date().toISOString(),
                collected_by: 'Counter Staff',
              }
            : b
        ),
      }))
    );
  };

  const updateProductStock = (productId: number, newStock: number) => {
    const val = Math.max(0, newStock);
    const oldP = products.find((p) => p.product_id === productId);
    setProducts((prev) =>
      prev.map((p) => (p.product_id === productId ? { ...p, stock_quantity: val } : p))
    );
    if (oldP) {
      logAudit('UPDATE_STOCK', 'products', productId, { stock_quantity: oldP.stock_quantity }, { stock_quantity: val });
    }
  };

  const toggleProductActive = (productId: number) => {
    const oldP = products.find((p) => p.product_id === productId);
    if (!oldP) return;
    const nextVal = !oldP.is_active;
    setProducts((prev) =>
      prev.map((p) => (p.product_id === productId ? { ...p, is_active: nextVal } : p))
    );
  };

  const resetDailyStock = (stallId: number) => {
    setProducts((prev) =>
      prev.map((p) =>
        p.stall_id === stallId ? { ...p, stock_quantity: p.daily_default_qty } : p
      )
    );
  };

  const proposeNewItem = (itemData: Partial<Product>) => {
    const stall = stalls.find((s) => s.stall_id === (itemData.stall_id || selectedVendorStallId))!;
    const canteen = canteens.find((c) => c.canteen_id === stall.canteen_id)!;
    const initialStatus = canteen.requires_approval ? 'pending' : 'published';

    const newProd: Product = {
      product_id: Date.now(),
      stall_id: stall.stall_id,
      canteen_id: canteen.canteen_id,
      product_name: itemData.product_name || 'New Item',
      category: itemData.category || 'Special',
      price: itemData.price || 50,
      stock_quantity: itemData.stock_quantity || 20,
      daily_default_qty: itemData.daily_default_qty || 20,
      prep_minutes: itemData.prep_minutes || 5,
      image_url: itemData.image_url || '/src/assets/images/canteen_burger_combo_1793624692365.jpg',
      is_veg: itemData.is_veg !== undefined ? itemData.is_veg : true,
      approval_status: initialStatus,
      is_active: true,
      description: itemData.description || 'Freshly made canteen special.',
      created_by: 101,
    };

    setProducts((prev) => [newProd, ...prev]);
  };

  const requestPriceChange = (productId: number, newPrice: number, reason: string) => {
    const prod = products.find((p) => p.product_id === productId);
    if (!prod) return;
    const stall = stalls.find((s) => s.stall_id === prod.stall_id);

    const newReq: PriceChangeRequest = {
      request_id: Date.now(),
      product_id: productId,
      product_name: prod.product_name,
      stall_name: stall?.stall_name || '',
      canteen_id: prod.canteen_id,
      old_price: prod.price,
      new_price: newPrice,
      reason,
      requested_by: 101,
      status: 'pending',
      created_at: new Date().toISOString(),
    };

    setPriceRequests((prev) => [newReq, ...prev]);
  };

  const setStallStatus = (
    stallId: number,
    status: StallStatus,
    pauseMinutes?: number,
    emergencyReason?: string
  ) => {
    let pausedUntil: string | null = null;
    if (status === 'paused' && pauseMinutes) {
      pausedUntil = new Date(Date.now() + pauseMinutes * 60 * 1000).toISOString();
    }

    setStalls((prev) =>
      prev.map((s) => (s.stall_id === stallId ? { ...s, status, paused_until: pausedUntil } : s))
    );

    if (status === 'closed' && emergencyReason) {
      setOrders((prev) =>
        prev.map((ord) => {
          const updatedBills = ord.bills.map((b) => {
            if (b.stall_id === stallId && (b.status === 'new' || b.status === 'accepted' || b.status === 'waiting_for_acceptance')) {
              const rf: Refund = {
                refund_id: Date.now() + b.stall_order_id,
                stall_order_id: b.stall_order_id,
                payment_id: ord.order_id,
                amount: b.total,
                destination: 'original',
                reason_code: 'STALL_EMERGENCY',
                gateway_refund_ref: `rfnd_${Date.now()}`,
                status: 'completed',
                created_at: new Date().toISOString(),
                stall_name: b.stall_name,
                bill_no: b.bill_no,
                details: `Emergency stop at stall: ${emergencyReason}. Auto-refund processed.`,
              };
              setRefunds((rList) => [rf, ...rList]);

              return {
                ...b,
                status: 'refunded' as const,
                cancelled_at: new Date().toISOString(),
                cancel_reason: emergencyReason,
              };
            }
            return b;
          });
          return { ...ord, bills: updatedBills };
        })
      );
    }
  };

  const approveProduct = (productId: number) => {
    setProducts((prev) =>
      prev.map((p) =>
        p.product_id === productId
          ? { ...p, approval_status: 'published', approved_by: 1, approved_at: new Date().toISOString() }
          : p
      )
    );
  };

  const rejectProduct = (productId: number, reason: string) => {
    setProducts((prev) =>
      prev.map((p) =>
        p.product_id === productId
          ? { ...p, approval_status: 'rejected', rejection_reason: reason }
          : p
      )
    );
  };

  const hideProduct = (productId: number) => {
    setProducts((prev) =>
      prev.map((p) => (p.product_id === productId ? { ...p, is_active: false } : p))
    );
  };

  const approvePriceRequest = (requestId: number) => {
    const req = priceRequests.find((r) => r.request_id === requestId);
    if (!req) return;

    setProducts((prev) =>
      prev.map((p) => (p.product_id === req.product_id ? { ...p, price: req.new_price } : p))
    );

    setPriceRequests((prev) =>
      prev.map((r) =>
        r.request_id === requestId
          ? { ...r, status: 'approved', decided_by: 1, decided_at: new Date().toISOString() }
          : r
      )
    );
  };

  const rejectPriceRequest = (requestId: number, reason: string) => {
    setPriceRequests((prev) =>
      prev.map((r) =>
        r.request_id === requestId
          ? { ...r, status: 'rejected', decided_by: 1, decided_at: new Date().toISOString(), decision_note: reason }
          : r
      )
    );
  };

  const copyYesterdaysMenu = (canteenId: number) => {
    setProducts((prev) =>
      prev.map((p) => (p.canteen_id === canteenId && p.approval_status === 'published' ? { ...p, is_active: true } : p))
    );
  };

  const toggleRequireApproval = (canteenId: number) => {
    const target = canteens.find((c) => c.canteen_id === canteenId);
    if (!target) return;
    const nextVal = !target.requires_approval;
    setCanteens((prev) =>
      prev.map((c) => (c.canteen_id === canteenId ? { ...c, requires_approval: nextVal } : c))
    );
  };

  const approveRefund = (refundId: number) => {
    setRefunds((prev) =>
      prev.map((rf) =>
        rf.refund_id === refundId
          ? { ...rf, status: 'completed', completed_at: new Date().toISOString(), approved_by: 1 }
          : rf
      )
    );
  };

  const updateCanteenSettings = (canteenId: number, updates: Partial<Canteen>) => {
    setCanteens((prev) =>
      prev.map((c) => (c.canteen_id === canteenId ? { ...c, ...updates } : c))
    );
  };

  const clearVendorAlert = () => setVendorAlertCount(0);

  const getLiveBusyLevel = (canteenId: number): 'Low' | 'Medium' | 'High' => {
    const canteenStalls = stalls.filter((s) => s.canteen_id === canteenId && s.status === 'open');
    if (canteenStalls.length === 0) return 'Low';

    const activeBillsCount = orders
      .filter((o) => o.status === 'paid' && o.canteen_id === canteenId)
      .flatMap((o) => o.bills)
      .filter(
        (b) =>
          b.status === 'waiting_for_acceptance' ||
          b.status === 'accepted' ||
          b.status === 'preparing' ||
          b.status === 'ready'
      ).length;

    const ratio = activeBillsCount / canteenStalls.length;
    if (ratio < 4) return 'Low';
    if (ratio < 12) return 'Medium';
    return 'High';
  };

  return (
    <CanteenContext.Provider
      value={{
        currentRole,
        setCurrentRole,
        selectedCanteenId,
        setSelectedCanteenId,
        selectedVendorStallId,
        setSelectedVendorStallId,
        currentUser,
        completeStudentLogin,
        logoutStudent,

        demoClockMultiplier,
        setDemoClockMultiplier,

        canteens,
        stalls,
        products,
        orders,
        priceRequests,
        refunds,
        auditLogs,
        ledger,

        cart,
        addToCart,
        updateCartQuantity,
        removeFromCart,
        clearCart,
        cartCanteen,
        pickupSlot,
        setPickupSlot,
        convenienceFee,

        stockShortages,
        clearShortages,
        handleShortageChoice,
        isHoldActive,
        holdSecondsLeft,
        activePendingOrder,
        holdExpiredCount,
        startCheckout,
        completeUpiPayment,
        cancelCheckoutHold,

        cancelStudentBill,
        getStudentBills,
        hasActiveOrder,

        vendorAcceptOrder,
        vendorRejectOrder,
        markBillReady,
        vendorCompleteByCode,
        markItemUnavailable,
        reopenExpiredBill,
        validateAndScanQr,
        handOverBill,
        updateProductStock,
        toggleProductActive,
        resetDailyStock,
        proposeNewItem,
        requestPriceChange,
        setStallStatus,
        vendorAlertCount,
        clearVendorAlert,

        approveProduct,
        rejectProduct,
        hideProduct,
        approvePriceRequest,
        rejectPriceRequest,
        copyYesterdaysMenu,
        toggleRequireApproval,
        approveRefund,
        updateCanteenSettings,

        calculateQrState,
        getLiveBusyLevel,
      }}
    >
      {children}
    </CanteenContext.Provider>
  );
};

export const useCanteen = () => {
  const context = useContext(CanteenContext);
  if (!context) {
    throw new Error('useCanteen must be used within a CanteenProvider');
  }
  return context;
};
