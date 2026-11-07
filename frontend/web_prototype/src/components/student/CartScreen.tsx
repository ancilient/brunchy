import React from 'react';
import { useCanteen } from '../../context/CanteenContext';
import { PickupSlot } from '../../types/canteen';
import {
  X,
  Plus,
  Minus,
  Trash2,
  ArrowRight,
  Clock,
  Store,
  Info,
  Check
} from 'lucide-react';

interface CartScreenProps {
  onBackToMenu: () => void;
  onProceedToPay: () => void;
  onShortageDetected: () => void;
}

export const CartScreen: React.FC<CartScreenProps> = ({
  onBackToMenu,
  onProceedToPay,
  onShortageDetected,
}) => {
  const {
    cart,
    updateCartQuantity,
    removeFromCart,
    clearCart,
    cartCanteen,
    pickupSlot,
    setPickupSlot,
    convenienceFee,
    startCheckout,
  } = useCanteen();

  // Group cart items by stall
  const itemsByStall: Record<
    number,
    {
      stall_name: string;
      stall_id: number;
      gst_rate: number;
      items: typeof cart;
    }
  > = {};

  cart.forEach((item) => {
    const sId = item.stall.stall_id;
    if (!itemsByStall[sId]) {
      itemsByStall[sId] = {
        stall_name: item.stall.stall_name,
        stall_id: sId,
        gst_rate: item.stall.gst_rate,
        items: [],
      };
    }
    itemsByStall[sId].items.push(item);
  });

  const stallKeys = Object.keys(itemsByStall).map(Number);

  // Subtotal & total calculations
  let subtotal = 0;
  let tax = 0;

  stallKeys.forEach((sId) => {
    const group = itemsByStall[sId];
    const stallSub = group.items.reduce((sum, it) => sum + it.product.price * it.quantity, 0);
    subtotal += stallSub;
    tax += (stallSub * group.gst_rate) / 100;
  });

  const grandTotal = Number((subtotal + tax + convenienceFee).toFixed(2));

  const handleCheckoutClick = () => {
    const res = startCheckout();
    if (res.shortage) {
      onShortageDetected();
    } else if (res.success) {
      onProceedToPay();
    } else if (res.message) {
      alert(res.message);
    }
  };

  const slotOptions: { id: PickupSlot; label: string; desc: string }[] = [
    { id: 'now', label: 'Now', desc: 'Cook immediately' },
    { id: '15_min_break', label: '15-min Break', desc: 'Ready for short break' },
    { id: '1_hour_break', label: '1-Hour Break', desc: 'Ready for lunch time' },
  ];

  return (
    <div className="w-full max-w-md mx-auto px-4 pt-3 pb-28">
      {/* Header */}
      <div className="flex items-center justify-between pb-3 border-b border-amber-200/60 mb-4">
        <div>
          <h2 className="text-xl font-bold text-slate-900 font-display">My Cart</h2>
          <p className="text-xs text-slate-500 mt-0.5">
            {cartCanteen?.canteen_name || 'Canteen'} · {cart.length} item{cart.length > 1 ? 's' : ''}
          </p>
        </div>
        {cart.length > 0 && (
          <button
            onClick={clearCart}
            className="text-xs text-slate-400 hover:text-rose-600 transition-colors flex items-center gap-1"
          >
            <Trash2 className="w-3.5 h-3.5" />
            <span>Clear</span>
          </button>
        )}
      </div>

      {cart.length === 0 ? (
        <div className="py-20 text-center bg-white rounded-3xl p-6 border border-amber-200/60 shadow-sm">
          <div className="w-16 h-16 rounded-full bg-[#FAF2E4] text-[#E63E11] flex items-center justify-center mx-auto mb-3">
            <Store className="w-8 h-8" />
          </div>
          <h3 className="text-base font-bold text-slate-800">Your Cart is Empty</h3>
          <p className="text-xs text-slate-500 mt-1 max-w-xs mx-auto">
            Choose freshly prepared burgers, juices and hot meals from your canteen!
          </p>
          <button
            onClick={onBackToMenu}
            className="mt-5 px-5 py-2.5 bg-gradient-to-r from-[#FF6E40] to-[#E63E11] text-white text-xs font-bold rounded-2xl shadow-md shadow-orange-500/25"
          >
            Browse Menu
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          {/* Pre-order Pickup Time Selector (per PDF open point) */}
          <div className="bg-white rounded-3xl p-4 border border-amber-200/80 shadow-xs">
            <div className="flex items-center gap-2 mb-2 text-xs font-bold text-slate-900">
              <Clock className="w-4 h-4 text-[#E63E11]" />
              <span>Pre-order for a break:</span>
            </div>
            <div className="grid grid-cols-3 gap-2">
              {slotOptions.map((opt) => {
                const isSelected = pickupSlot === opt.id;
                return (
                  <button
                    key={opt.id}
                    onClick={() => setPickupSlot(opt.id)}
                    className={`py-2 px-1.5 rounded-2xl text-center border transition-all ${
                      isSelected
                        ? 'bg-orange-50 border-[#E63E11] text-[#E63E11] font-bold shadow-xs'
                        : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                    }`}
                  >
                    <span className="text-xs block leading-tight">{opt.label}</span>
                    <span className="text-[9px] text-slate-400 block mt-0.5">{opt.desc}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Stall Item Blocks */}
          {stallKeys.map((sId, idx) => {
            const group = itemsByStall[sId];
            const stallSub = group.items.reduce(
              (sum, it) => sum + it.product.price * it.quantity,
              0
            );

            return (
              <div
                key={sId}
                className="bg-white rounded-3xl p-4 border border-amber-200/80 shadow-xs space-y-3"
              >
                <div className="flex items-center justify-between pb-2 border-b border-slate-100 text-xs">
                  <span className="font-bold text-slate-900 font-display">
                    {group.stall_name}
                  </span>
                  <span className="text-[10px] bg-orange-100 text-[#E63E11] font-bold px-2 py-0.5 rounded-full">
                    Separate Bill & 3-Digit Code
                  </span>
                </div>

                <div className="space-y-2.5">
                  {group.items.map((item) => (
                    <div
                      key={item.product.product_id}
                      className="flex items-center justify-between gap-2 text-xs"
                    >
                      <div className="flex items-center gap-2 flex-1 min-w-0">
                        <span className="font-medium text-slate-900 truncate">
                          {item.product.product_name}
                        </span>
                      </div>

                      {/* Stepper */}
                      <div className="flex items-center gap-1.5 bg-[#FAF2E4] px-2 py-1 rounded-full border border-amber-200">
                        <button
                          onClick={() => updateCartQuantity(item.product.product_id, -1)}
                          className="w-5 h-5 rounded-full bg-white text-slate-700 flex items-center justify-center text-xs"
                        >
                          <Minus className="w-3 h-3" />
                        </button>
                        <span className="text-xs font-mono font-bold text-slate-900 min-w-[14px] text-center">
                          {item.quantity}
                        </span>
                        <button
                          onClick={() => updateCartQuantity(item.product.product_id, 1)}
                          className="w-5 h-5 rounded-full bg-[#E63E11] text-white flex items-center justify-center text-xs"
                        >
                          <Plus className="w-3 h-3" />
                        </button>
                      </div>

                      <div className="font-mono font-bold text-slate-900 min-w-[50px] text-right">
                        ₹{item.product.price * item.quantity}
                      </div>
                    </div>
                  ))}
                </div>

                <div className="pt-2 border-t border-slate-100 flex justify-between items-center text-[11px] text-slate-500">
                  <span>Stall Subtotal:</span>
                  <span className="font-mono font-bold text-slate-800">₹{stallSub}</span>
                </div>
              </div>
            );
          })}

          {/* Bill Breakdown with Convenience Fee */}
          <div className="bg-white rounded-3xl p-4 border border-amber-200/80 shadow-xs space-y-2 text-xs text-slate-600">
            <div className="flex justify-between">
              <span>Item Total</span>
              <span className="font-mono font-medium text-slate-900">₹{subtotal}</span>
            </div>
            {tax > 0 && (
              <div className="flex justify-between">
                <span>GST Tax</span>
                <span className="font-mono font-medium text-slate-900">₹{tax.toFixed(2)}</span>
              </div>
            )}
            <div className="flex justify-between text-[#E63E11] font-medium">
              <span className="flex items-center gap-1">
                <span>Convenience Fee</span>
                <Info className="w-3 h-3 text-slate-400" />
              </span>
              <span className="font-mono">₹{convenienceFee}</span>
            </div>
            <div className="pt-2 border-t border-slate-100 flex justify-between items-center text-sm font-bold text-slate-900">
              <span>To Pay</span>
              <span className="font-mono text-lg text-[#E63E11]">₹{grandTotal}</span>
            </div>
          </div>

          {/* Pay Button */}
          <button
            onClick={handleCheckoutClick}
            className="w-full py-4 bg-gradient-to-r from-[#FF6E40] to-[#E63E11] hover:from-[#f56133] hover:to-[#d63408] text-white rounded-2xl font-bold text-sm flex items-center justify-center gap-2 shadow-xl shadow-orange-500/25 active:scale-[0.98] transition-all"
          >
            <span>Pay ₹{grandTotal}</span>
            <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      )}
    </div>
  );
};
