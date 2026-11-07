import React from 'react';
import { useCanteen } from '../../context/CanteenContext';
import { X, Plus, Minus, Trash2, ArrowRight, Store, AlertCircle } from 'lucide-react';

interface CartDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  onProceedToPayment: () => void;
  onShortageDetected: () => void;
}

export const CartDrawer: React.FC<CartDrawerProps> = ({
  isOpen,
  onClose,
  onProceedToPayment,
  onShortageDetected,
}) => {
  const {
    cart,
    updateCartQuantity,
    removeFromCart,
    clearCart,
    cartCanteen,
    startCheckout,
  } = useCanteen();

  if (!isOpen) return null;

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

  const calculateGrandTotal = () => {
    let grandSubtotal = 0;
    let grandTax = 0;

    stallKeys.forEach((sId) => {
      const stallGroup = itemsByStall[sId];
      const stallSub = stallGroup.items.reduce(
        (sum, it) => sum + it.product.price * it.quantity,
        0
      );
      const stallTax = (stallSub * stallGroup.gst_rate) / 100;
      grandSubtotal += stallSub;
      grandTax += stallTax;
    });

    return {
      subtotal: grandSubtotal,
      tax: grandTax,
      total: Number((grandSubtotal + grandTax).toFixed(2)),
    };
  };

  const { subtotal, tax, total } = calculateGrandTotal();

  const handleCheckoutClick = () => {
    const res = startCheckout();
    if (res.shortage) {
      onShortageDetected();
    } else if (res.success) {
      onClose();
      onProceedToPayment();
    } else if (res.message) {
      alert(res.message);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-black/60 backdrop-blur-sm animate-in fade-in duration-150">
      <div className="w-full max-w-md bg-white h-full shadow-2xl flex flex-col justify-between overflow-hidden animate-in slide-in-from-right duration-200">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100 bg-slate-50/60">
          <div>
            <h3 className="text-xl font-bold text-slate-900 font-display">My Cart</h3>
            <div className="text-xs text-slate-500 mt-0.5 flex items-center gap-1.5">
              <span className="font-semibold text-indigo-700">{cartCanteen?.canteen_name || 'Canteen'}</span>
              <span>·</span>
              <span>{stallKeys.length} {stallKeys.length === 1 ? 'stall' : 'stalls'} = {stallKeys.length} {stallKeys.length === 1 ? 'bill' : 'separate bills'}</span>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {cart.length > 0 && (
              <button
                onClick={clearCart}
                className="text-xs text-slate-400 hover:text-rose-600 transition-colors p-1"
                title="Clear Cart"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            )}
            <button
              onClick={onClose}
              className="w-9 h-9 flex items-center justify-center rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-200/60 transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          {cart.length === 0 ? (
            <div className="py-20 text-center">
              <div className="w-16 h-16 rounded-2xl bg-indigo-50 text-indigo-500 flex items-center justify-center mx-auto mb-3">
                <Store className="w-8 h-8" />
              </div>
              <h4 className="text-base font-semibold text-slate-800">Your cart is empty</h4>
              <p className="text-xs text-slate-400 mt-1 max-w-xs mx-auto">
                Explore delicious items from our stalls and add them to your cart.
              </p>
            </div>
          ) : (
            <>
              {stallKeys.map((sId, index) => {
                const group = itemsByStall[sId];
                const stallSub = group.items.reduce(
                  (sum, it) => sum + it.product.price * it.quantity,
                  0
                );
                const stallTax = Number(((stallSub * group.gst_rate) / 100).toFixed(2));
                const stallTotal = stallSub + stallTax;

                return (
                  <div
                    key={sId}
                    className="p-4 rounded-2xl border border-slate-200/90 bg-white shadow-sm"
                  >
                    {/* Stall Bill Title */}
                    <div className="flex items-center justify-between pb-3 border-b border-slate-100 mb-3">
                      <div className="flex items-center gap-2">
                        <span className="text-[10px] font-bold uppercase tracking-wider bg-slate-100 text-slate-700 px-2 py-0.5 rounded-md">
                          BILL {index + 1}
                        </span>
                        <h4 className="text-sm font-bold text-slate-900 font-display">
                          {group.stall_name}
                        </h4>
                      </div>
                      <span className="text-xs text-slate-400">
                        {group.gst_rate > 0 ? `${group.gst_rate}% GST` : '0% GST'}
                      </span>
                    </div>

                    {/* Stall Items */}
                    <div className="space-y-3">
                      {group.items.map((item) => (
                        <div
                          key={item.product.product_id}
                          className="flex items-center justify-between gap-3 text-sm"
                        >
                          <div className="flex items-center gap-2 flex-1 min-w-0">
                            {/* Veg / Non-Veg Indicator */}
                            <span
                              className={`w-3.5 h-3.5 border flex items-center justify-center p-0.5 rounded shrink-0 ${
                                item.product.is_veg
                                  ? 'border-emerald-600'
                                  : 'border-rose-600'
                              }`}
                            >
                              <span
                                className={`w-1.5 h-1.5 rounded-full ${
                                  item.product.is_veg
                                    ? 'bg-emerald-600'
                                    : 'bg-rose-600'
                                }`}
                              />
                            </span>
                            <span className="text-xs font-semibold text-slate-800 truncate">
                              {item.product.product_name}
                            </span>
                          </div>

                          {/* Stepper */}
                          <div className="flex items-center gap-2 bg-slate-100 px-2 py-1 rounded-lg">
                            <button
                              onClick={() => updateCartQuantity(item.product.product_id, -1)}
                              className="text-slate-600 hover:text-slate-900"
                            >
                              <Minus className="w-3.5 h-3.5" />
                            </button>
                            <span className="text-xs font-bold font-mono text-slate-900 min-w-[16px] text-center">
                              {item.quantity}
                            </span>
                            <button
                              onClick={() => updateCartQuantity(item.product.product_id, 1)}
                              className="text-slate-600 hover:text-slate-900"
                            >
                              <Plus className="w-3.5 h-3.5" />
                            </button>
                          </div>

                          {/* Line total */}
                          <div className="text-xs font-bold font-mono text-slate-900 min-w-[50px] text-right">
                            Rs. {item.product.price * item.quantity}
                          </div>
                        </div>
                      ))}
                    </div>

                    {/* Bill Sub-totals */}
                    <div className="mt-3 pt-2.5 border-t border-slate-100 flex justify-between items-center text-xs text-slate-500">
                      <span>Stall Bill Total:</span>
                      <span className="font-mono font-bold text-slate-900">Rs. {stallTotal}</span>
                    </div>
                  </div>
                );
              })}

              <div className="p-3 bg-blue-50/60 border border-blue-100 rounded-xl text-xs text-blue-900 flex items-start gap-2">
                <AlertCircle className="w-4 h-4 text-blue-600 shrink-0 mt-0.5" />
                <span>
                  Each stall prepares food independently and issues its own bill number, token, and pickup QR.
                </span>
              </div>
            </>
          )}
        </div>

        {/* Footer with Grand Total & Checkout */}
        {cart.length > 0 && (
          <div className="p-6 border-t border-slate-100 bg-white space-y-4">
            <div className="space-y-1.5 text-xs text-slate-600">
              <div className="flex justify-between">
                <span>Subtotal ({cart.reduce((s, i) => s + i.quantity, 0)} items)</span>
                <span className="font-mono font-medium text-slate-800">Rs. {subtotal}</span>
              </div>
              {tax > 0 && (
                <div className="flex justify-between">
                  <span>Stall Taxes (GST)</span>
                  <span className="font-mono font-medium text-slate-800">Rs. {tax}</span>
                </div>
              )}
              <div className="flex justify-between text-base font-bold text-slate-900 pt-2 border-t border-slate-100">
                <span>Total to Pay</span>
                <span className="font-mono text-[#3A3D9E]">Rs. {total}</span>
              </div>
            </div>

            <button
              onClick={handleCheckoutClick}
              className="w-full h-12 bg-[#3A3D9E] hover:bg-indigo-700 text-white rounded-xl text-sm font-bold flex items-center justify-center gap-2 shadow-lg shadow-indigo-600/20 active:scale-[0.98] transition-all"
            >
              <span>Proceed to Checkout</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        )}
      </div>
    </div>
  );
};
