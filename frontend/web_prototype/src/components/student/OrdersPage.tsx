import React, { useState } from 'react';
import { useCanteen } from '../../context/CanteenContext';
import { StallBill } from '../../types/canteen';
import { CustomerCareModal } from './CustomerCareModal';
import {
  HelpCircle,
  Clock,
  CheckCircle2,
  AlertCircle,
  ArrowLeft,
  Sparkles,
  ShoppingBag,
  RotateCcw,
  Check
} from 'lucide-react';

interface OrdersPageProps {
  onBackToMenu: () => void;
}

export const OrdersPage: React.FC<OrdersPageProps> = ({ onBackToMenu }) => {
  const {
    getStudentBills,
    cancelStudentBill,
    vendorAcceptOrder,
    handOverBill,
  } = useCanteen();
  const [showCustomerCare, setShowCustomerCare] = useState<boolean>(false);

  const bills = getStudentBills();

  return (
    <div className="w-full max-w-md mx-auto px-4 pt-3 pb-28">
      {/* Top Header with Customer Care Button at top right per PDF! */}
      <div className="flex items-center justify-between pb-3 border-b border-amber-200/60 mb-5">
        <div className="flex items-center gap-2">
          <button
            onClick={onBackToMenu}
            className="w-8 h-8 rounded-full bg-white border border-amber-200 flex items-center justify-center text-slate-700 hover:bg-slate-50 transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
          </button>
          <div>
            <h2 className="text-xl font-bold text-slate-900 font-display">My Orders</h2>
            <p className="text-[11px] text-slate-500">Live tokens & bills</p>
          </div>
        </div>

        {/* Customer Care Button at Top Right (Screen 7 of PDF) */}
        <button
          onClick={() => setShowCustomerCare(true)}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-2xl bg-orange-50 hover:bg-orange-100 text-[#E63E11] border border-orange-200 text-xs font-bold transition-colors shadow-xs"
        >
          <HelpCircle className="w-4 h-4" />
          <span>Customer Care</span>
        </button>
      </div>

      {bills.length === 0 ? (
        <div className="py-20 text-center bg-white rounded-3xl p-6 border border-amber-200/60 shadow-sm">
          <div className="w-16 h-16 rounded-full bg-[#FAF2E4] text-[#E63E11] flex items-center justify-center mx-auto mb-3">
            <ShoppingBag className="w-8 h-8" />
          </div>
          <h3 className="text-base font-bold text-slate-800">No Orders Yet</h3>
          <p className="text-xs text-slate-500 mt-1 max-w-xs mx-auto">
            Order from the canteen to receive your 3-digit pickup code!
          </p>
          <button
            onClick={onBackToMenu}
            className="mt-5 px-5 py-2.5 bg-gradient-to-r from-[#FF6E40] to-[#E63E11] text-white text-xs font-bold rounded-2xl shadow-md shadow-orange-500/25"
          >
            Explore Menu
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          {bills.map((bill) => {
            const isWaiting = bill.status === 'waiting_for_acceptance';
            const isAccepted = bill.status === 'accepted' || bill.status === 'preparing' || bill.status === 'ready';
            const isCompleted = bill.status === 'completed' || bill.status === 'collected' || bill.is_blurred_sealed;
            const isRefunded = bill.status === 'refunded' || bill.status === 'rejected';
            const isExpired = bill.status === 'expired';

            return (
              <div
                key={bill.stall_order_id}
                className={`relative rounded-3xl overflow-hidden border transition-all ${
                  isCompleted
                    ? 'border-slate-300 bg-slate-100/70 shadow-none'
                    : isWaiting
                    ? 'border-amber-300 bg-white shadow-sm'
                    : 'border-orange-200 bg-white shadow-md'
                }`}
              >
                {/* Blurred / Sealed Stamp Overlay for Completed Orders per PDF! */}
                {isCompleted && (
                  <div className="absolute inset-0 z-20 backdrop-blur-[2px] bg-slate-200/40 flex items-center justify-center pointer-events-none">
                    <div className="border-4 border-slate-600/70 rounded-2xl px-6 py-2 transform -rotate-12 bg-white/80 shadow-md">
                      <span className="text-xl font-extrabold uppercase tracking-widest text-slate-700 font-display block">
                        COMPLETED
                      </span>
                      <span className="text-[10px] text-slate-500 font-bold uppercase tracking-wider block text-center">
                        Sealed · Cannot be reused
                      </span>
                    </div>
                  </div>
                )}

                {/* Bill Header */}
                <div className="p-4 border-b border-slate-100 flex items-center justify-between">
                  <div>
                    <span className="text-xs font-semibold text-slate-500 block uppercase tracking-wider">
                      {bill.stall_name}
                    </span>
                    <h3 className="text-base font-bold text-slate-900 font-display">
                      Bill {bill.bill_no || '#ORDER'}
                    </h3>
                  </div>

                  <div>
                    {isWaiting && (
                      <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-amber-100 text-amber-800 flex items-center gap-1 animate-pulse">
                        <Clock className="w-3.5 h-3.5 text-amber-600" />
                        Waiting for Acceptance
                      </span>
                    )}

                    {isAccepted && (
                      <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-100 text-emerald-800 flex items-center gap-1">
                        <Sparkles className="w-3.5 h-3.5 text-emerald-600" />
                        Accepted & Cooking
                      </span>
                    )}

                    {isCompleted && (
                      <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-slate-200 text-slate-700 flex items-center gap-1">
                        <Check className="w-3.5 h-3.5" />
                        Handed Over
                      </span>
                    )}

                    {isRefunded && (
                      <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-purple-100 text-purple-700">
                        Refunded
                      </span>
                    )}
                  </div>
                </div>

                {/* 3-Digit Pickup Code Box (Screen 8 of PDF) */}
                <div className="p-4 bg-orange-50/50 border-b border-orange-100">
                  {isRefunded || isExpired ? (
                    <div className="text-center py-2">
                      <p className="text-xs font-bold text-purple-800">
                        {isExpired ? 'Pickup window expired' : bill.status === 'rejected' ? 'The stall could not take this order' : 'Order cancelled'}
                      </p>
                      <p className="text-[11px] text-slate-500 mt-1">
                        {isExpired ? 'This bill can no longer be collected.' : `₹${bill.total} is being refunded to your original payment method.`}
                        {bill.cancel_reason && !isExpired ? ` Reason: ${bill.cancel_reason}.` : ''}
                      </p>
                    </div>
                  ) : isWaiting ? (
                    <div className="text-center py-2">
                      <p className="text-xs font-bold text-amber-900">
                        Order sent; waiting for the stall to accept...
                      </p>
                      <p className="text-[11px] text-slate-500 mt-1">
                        Stall staff has been alerted. Your 3-digit pickup code will appear right here as soon as accepted.
                      </p>
                    </div>
                  ) : (
                    <div className="flex items-center justify-between">
                      <div>
                        <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">
                          Counter Pickup Code:
                        </span>
                        <div className="text-4xl font-extrabold text-[#E63E11] font-mono tracking-widest mt-0.5">
                          {bill.pickup_code || '---'}
                        </div>
                      </div>

                      <div className="text-right">
                        <span className="text-[10px] font-semibold text-slate-500 block">
                          Estimated Time:
                        </span>
                        <span className="text-xs font-bold text-slate-900 font-mono">
                          ~{bill.estimated_time_mins || 6} mins ({bill.estimated_ready_time || 'Ready soon'})
                        </span>
                        <p className="text-[10px] text-emerald-700 font-medium mt-0.5">
                          Tell this code to counter staff
                        </p>
                      </div>
                    </div>
                  )}

                  {isAccepted && !isCompleted && (
                    <div className="mt-2 text-[10px] text-slate-500 bg-white/80 p-2 rounded-xl border border-amber-200/50">
                      💡 Note: Works when the order is Ready. The vendor types it to hand over your food.
                    </div>
                  )}
                </div>

                {/* Order Details & Items */}
                <div className="p-4 space-y-2 text-xs">
                  <div className="text-slate-400 text-[10px]">
                    Ordered: {new Date(bill.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </div>

                  <div className="space-y-1.5 pt-1">
                    {bill.items.map((it) => (
                      <div key={it.item_id} className="flex justify-between items-center text-slate-800">
                        <span className="font-semibold">
                          {it.quantity}x {it.product_name}
                          {it.item_status === 'unavailable_refunded' && (
                            <span className="ml-1 text-rose-600 font-bold">(Unavailable - Refunded)</span>
                          )}
                        </span>
                        <span className="font-mono text-slate-900">
                          ₹{it.price * it.quantity}
                        </span>
                      </div>
                    ))}
                  </div>

                  <div className="pt-2 border-t border-slate-100 flex justify-between items-center font-bold text-slate-900">
                    <span>{isRefunded ? 'Refunded' : 'Total Paid'}</span>
                    <span className="font-mono text-[#E63E11]">₹{bill.total}</span>
                  </div>

                  {/* Interactive actions for student flow demonstration */}
                  {isWaiting && (
                    <div className="pt-3 space-y-2">
                      <button
                        onClick={() => vendorAcceptOrder(bill.stall_order_id, 6)}
                        className="w-full py-2 bg-emerald-50 hover:bg-emerald-100 text-emerald-800 rounded-xl text-xs font-bold border border-emerald-200 transition-colors flex items-center justify-center gap-1.5"
                      >
                        <Sparkles className="w-3.5 h-3.5 text-emerald-600" />
                        <span>Simulate Kitchen Acceptance</span>
                      </button>

                      <button
                        onClick={() => {
                          if (confirm('Cancel this bill? You will receive an immediate full refund.')) {
                            cancelStudentBill(bill.stall_order_id);
                          }
                        }}
                        className="w-full py-2 bg-rose-50 hover:bg-rose-100 text-rose-700 rounded-xl text-xs font-bold border border-rose-200 transition-colors"
                      >
                        Cancel & Instant Refund (₹{bill.total})
                      </button>
                    </div>
                  )}

                  {isAccepted && !isCompleted && (
                    <div className="pt-3">
                      <button
                        onClick={() => handOverBill(bill.stall_order_id)}
                        className="w-full py-2.5 bg-gradient-to-r from-[#FF6E40] to-[#E63E11] hover:from-[#f56133] hover:to-[#d63408] text-white rounded-xl text-xs font-bold shadow-md shadow-orange-500/20 flex items-center justify-center gap-1.5 transition-all active:scale-[0.98]"
                      >
                        <Check className="w-3.5 h-3.5 stroke-[3]" />
                        <span>Tell Code {bill.pickup_code} at Counter (Hand Over & Seal)</span>
                      </button>
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Customer Care Modal */}
      {showCustomerCare && (
        <CustomerCareModal onClose={() => setShowCustomerCare(false)} />
      )}
    </div>
  );
};
