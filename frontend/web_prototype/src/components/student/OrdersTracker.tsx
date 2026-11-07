import React, { useState } from 'react';
import { useCanteen } from '../../context/CanteenContext';
import { StallBill } from '../../types/canteen';
import { QRCodeModal } from '../common/QRCodeModal';
import {
  QrCode,
  Clock,
  CheckCircle2,
  AlertTriangle,
  RefreshCw,
  ShoppingBag,
  ArrowLeft,
  ChevronRight,
  ShieldAlert,
  Sparkles
} from 'lucide-react';

interface OrdersTrackerProps {
  onBackToMenu: () => void;
}

export const OrdersTracker: React.FC<OrdersTrackerProps> = ({ onBackToMenu }) => {
  const { getStudentBills, cancelStudentBill, calculateQrState } = useCanteen();
  const [activeQrBill, setActiveQrBill] = useState<StallBill | null>(null);

  const bills = getStudentBills();

  const getStatusBadge = (bill: StallBill) => {
    const { state, secondsLeft } = calculateQrState(bill);

    if (bill.status === 'collected') {
      return (
        <span className="px-2.5 py-1 rounded-lg text-xs font-bold bg-slate-100 text-slate-700 flex items-center gap-1">
          <CheckCircle2 className="w-3.5 h-3.5 text-slate-500" />
          COLLECTED
        </span>
      );
    }
    if (bill.status === 'refunded') {
      return (
        <span className="px-2.5 py-1 rounded-lg text-xs font-bold bg-purple-100 text-purple-700">
          REFUNDED
        </span>
      );
    }
    if (bill.status === 'ready') {
      if (state === 'active') {
        const mins = Math.floor(secondsLeft / 60);
        const secs = secondsLeft % 60;
        return (
          <span className="px-2.5 py-1 rounded-lg text-xs font-bold bg-emerald-100 text-emerald-800 flex items-center gap-1 animate-pulse">
            <Sparkles className="w-3.5 h-3.5 text-emerald-600" />
            READY · {String(mins).padStart(2, '0')}:{String(secs).padStart(2, '0')}
          </span>
        );
      } else if (state === 'grace') {
        return (
          <span className="px-2.5 py-1 rounded-lg text-xs font-bold bg-amber-100 text-amber-800 flex items-center gap-1">
            <AlertTriangle className="w-3.5 h-3.5 text-amber-600" />
            GRACE PERIOD
          </span>
        );
      } else {
        return (
          <span className="px-2.5 py-1 rounded-lg text-xs font-bold bg-rose-100 text-rose-800">
            EXPIRED
          </span>
        );
      }
    }
    if (bill.status === 'preparing') {
      return (
        <span className="px-2.5 py-1 rounded-lg text-xs font-bold bg-blue-100 text-blue-800 flex items-center gap-1">
          <Clock className="w-3.5 h-3.5 text-blue-600 animate-spin" />
          PREPARING
        </span>
      );
    }
    if (bill.status === 'accepted') {
      return (
        <span className="px-2.5 py-1 rounded-lg text-xs font-bold bg-sky-100 text-sky-800">
          ACCEPTED
        </span>
      );
    }
    return (
      <span className="px-2.5 py-1 rounded-lg text-xs font-bold bg-indigo-100 text-indigo-800">
        NEW ORDER
      </span>
    );
  };

  return (
    <div className="max-w-3xl mx-auto px-4 py-8">
      {/* Top Header */}
      <div className="flex items-center justify-between mb-6">
        <button
          onClick={onBackToMenu}
          className="flex items-center gap-1.5 text-xs font-bold text-slate-600 hover:text-slate-900 bg-white border border-slate-200 px-3 py-1.5 rounded-xl shadow-xs transition-colors"
        >
          <ArrowLeft className="w-3.5 h-3.5" />
          <span>Back to Menu</span>
        </button>
        <h2 className="text-xl font-bold text-slate-900 font-display">My Orders & Tokens</h2>
        <span className="text-xs text-slate-500 font-mono">{bills.length} bills</span>
      </div>

      {bills.length === 0 ? (
        <div className="py-20 text-center bg-white rounded-3xl border border-slate-200 p-8">
          <div className="w-16 h-16 rounded-2xl bg-indigo-50 text-indigo-600 flex items-center justify-center mx-auto mb-3">
            <ShoppingBag className="w-8 h-8" />
          </div>
          <h3 className="text-base font-bold text-slate-900">No Orders Placed Yet</h3>
          <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
            Choose a canteen and place your favorite meals with instant UPI checkout!
          </p>
          <button
            onClick={onBackToMenu}
            className="mt-5 px-5 py-2.5 bg-[#3A3D9E] text-white text-xs font-bold rounded-xl hover:bg-indigo-700 transition-colors shadow-sm"
          >
            Explore Menu
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          {bills.map((bill) => {
            const { state, secondsLeft } = calculateQrState(bill);
            const isReady = bill.status === 'ready';
            const canCancel = bill.status === 'new' || bill.status === 'accepted';

            return (
              <div
                key={bill.stall_order_id}
                className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden hover:shadow-md transition-shadow"
              >
                {/* Stall & Bill Header */}
                <div className="p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-100 bg-slate-50/50">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-indigo-50 border border-indigo-100 flex items-center justify-center font-bold text-indigo-700 font-mono text-sm">
                      {bill.bill_prefix}
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <h4 className="text-base font-bold text-slate-900 font-display">
                          {bill.stall_name}
                        </h4>
                        <span className="text-xs font-mono font-bold text-slate-600 bg-white border border-slate-200 px-2 py-0.5 rounded-md">
                          {bill.bill_no}
                        </span>
                      </div>
                      <p className="text-xs text-slate-400 mt-0.5">
                        {new Date(bill.created_at).toLocaleTimeString([], {
                          hour: '2-digit',
                          minute: '2-digit',
                        })}{' '}
                        · Paid via UPI
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    {getStatusBadge(bill)}
                  </div>
                </div>

                {/* Items and QR Action */}
                <div className="p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-5">
                  {/* Items List */}
                  <div className="flex-1 space-y-1.5">
                    {bill.items.map((it) => (
                      <div
                        key={it.item_id}
                        className="flex items-center justify-between text-xs text-slate-700"
                      >
                        <span className="font-medium">
                          {it.quantity}x {it.product_name}
                          {it.item_status === 'unavailable_refunded' && (
                            <span className="ml-1 text-rose-600 font-semibold">(Refunded)</span>
                          )}
                        </span>
                        <span className="font-mono text-slate-900">
                          Rs. {it.price * it.quantity}
                        </span>
                      </div>
                    ))}
                    <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-xs font-bold text-slate-900">
                      <span>Stall Bill Total</span>
                      <span className="font-mono text-indigo-700">Rs. {bill.total}</span>
                    </div>
                  </div>

                  {/* QR Token Button */}
                  <div className="sm:border-l sm:border-slate-100 sm:pl-5 flex flex-col items-center sm:items-end justify-center gap-2">
                    {bill.status === 'collected' ? (
                      <div className="text-center sm:text-right">
                        <div className="inline-flex items-center gap-1 text-xs text-slate-500 font-medium">
                          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500" />
                          Handed over at counter
                        </div>
                        <p className="text-[10px] text-slate-400">
                          {bill.collected_at ? new Date(bill.collected_at).toLocaleTimeString() : ''}
                        </p>
                      </div>
                    ) : (
                      <button
                        onClick={() => setActiveQrBill(bill)}
                        className={`w-full sm:w-auto px-4 py-2.5 rounded-xl font-bold text-xs flex items-center justify-center gap-2 shadow-sm transition-all ${
                          isReady
                            ? 'bg-emerald-600 hover:bg-emerald-700 text-white animate-bounce'
                            : 'bg-[#3A3D9E] hover:bg-indigo-700 text-white'
                        }`}
                      >
                        <QrCode className="w-4 h-4" />
                        <span>
                          {isReady ? 'SHOW PICKUP QR CODE' : 'View Bill & Token'}
                        </span>
                      </button>
                    )}

                    {/* Student cancel option */}
                    {canCancel && (
                      <button
                        onClick={() => {
                          if (
                            confirm(
                              `Cancel bill ${bill.bill_no}? You will receive an immediate full refund of Rs. ${bill.total} to your original payment method.`
                            )
                          ) {
                            cancelStudentBill(bill.stall_order_id);
                          }
                        }}
                        className="text-[11px] font-semibold text-rose-600 hover:text-rose-700 underline"
                      >
                        Cancel Bill & Refund (Rs. {bill.total})
                      </button>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* QR Code Full Modal */}
      {activeQrBill && (
        <QRCodeModal bill={activeQrBill} onClose={() => setActiveQrBill(null)} />
      )}
    </div>
  );
};
