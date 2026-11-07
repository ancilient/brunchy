import React, { useEffect, useState } from 'react';
import QRCode from 'qrcode';
import { StallBill, QRState } from '../../types/canteen';
import { useCanteen } from '../../context/CanteenContext';
import { X, Clock, AlertTriangle, CheckCircle2, ShieldAlert, Sparkles } from 'lucide-react';

interface QRCodeModalProps {
  bill: StallBill;
  onClose: () => void;
}

export const QRCodeModal: React.FC<QRCodeModalProps> = ({ bill, onClose }) => {
  const { calculateQrState, cancelStudentBill } = useCanteen();
  const [qrDataUrl, setQrDataUrl] = useState<string>('');
  const [copied, setCopied] = useState<boolean>(false);

  const { state: qrState, secondsLeft, label } = calculateQrState(bill);

  useEffect(() => {
    if (bill.qr_token) {
      QRCode.toDataURL(bill.qr_token, {
        width: 260,
        margin: 2,
        color: {
          dark: qrState === 'expired' ? '#DC2626' : qrState === 'active' ? '#16A34A' : '#1E293B',
          light: '#FFFFFF',
        },
      })
        .then((url) => setQrDataUrl(url))
        .catch((err) => console.error(err));
    }
  }, [bill.qr_token, qrState]);

  const formatCountdown = (totalSec: number) => {
    const mins = Math.floor(totalSec / 60);
    const secs = totalSec % 60;
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  };

  const getHeaderStyle = () => {
    switch (qrState) {
      case 'active':
        return 'bg-emerald-50 text-emerald-800 border-emerald-200';
      case 'grace':
        return 'bg-amber-50 text-amber-800 border-amber-200';
      case 'expired':
        return 'bg-rose-50 text-rose-800 border-rose-200';
      case 'used':
        return 'bg-slate-100 text-slate-700 border-slate-200';
      default:
        return 'bg-indigo-50 text-indigo-800 border-indigo-200';
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="relative w-full max-w-sm bg-white rounded-3xl shadow-2xl border border-slate-100 overflow-hidden">
        {/* Top Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-slate-100 bg-slate-50/50">
          <div>
            <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">
              Counter Token & Bill
            </div>
            <div className="text-lg font-bold text-slate-900 font-display">
              {bill.stall_name}
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-9 h-9 flex items-center justify-center rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-200/60 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Status Banner */}
        <div className={`px-4 py-2.5 border-b text-center text-xs font-medium ${getHeaderStyle()}`}>
          {qrState === 'locked' && (
            <div className="flex items-center justify-center gap-1.5">
              <Clock className="w-3.5 h-3.5" />
              <span>QR activates when the stall marks your order ready</span>
            </div>
          )}
          {qrState === 'active' && (
            <div className="flex items-center justify-center gap-1.5 font-semibold text-emerald-700">
              <Sparkles className="w-4 h-4 text-emerald-600 animate-spin" />
              <span>READY FOR PICKUP · {formatCountdown(secondsLeft)} left</span>
            </div>
          )}
          {qrState === 'grace' && (
            <div className="flex items-center justify-center gap-1.5 font-semibold text-amber-700">
              <AlertTriangle className="w-4 h-4 text-amber-600" />
              <span>HURRY! 3-Min Grace Period · {formatCountdown(secondsLeft)} left</span>
            </div>
          )}
          {qrState === 'expired' && (
            <div className="flex items-center justify-center gap-1.5 font-semibold text-rose-700">
              <ShieldAlert className="w-4 h-4 text-rose-600" />
              <span>Order Expired · Unclaimed food policy applied</span>
            </div>
          )}
          {qrState === 'used' && (
            <div className="flex items-center justify-center gap-1.5 font-semibold text-slate-600">
              <CheckCircle2 className="w-4 h-4 text-slate-500" />
              <span>Order Completed & Collected</span>
            </div>
          )}
        </div>

        {/* QR Body */}
        <div className="p-6 flex flex-col items-center">
          <div className="relative p-3 bg-white rounded-2xl border-2 border-dashed border-slate-200 shadow-inner">
            {qrState === 'locked' ? (
              <div className="w-56 h-56 flex flex-col items-center justify-center bg-slate-50 rounded-xl p-4 text-center">
                <Clock className="w-12 h-12 text-slate-300 mb-2 animate-pulse" />
                <p className="text-sm font-semibold text-slate-700">Kitchen is Preparing</p>
                <p className="text-xs text-slate-400 mt-1">
                  Bill {bill.bill_no} will generate active pickup QR once cooked
                </p>
              </div>
            ) : qrDataUrl ? (
              <div className="relative">
                <img
                  src={qrDataUrl}
                  alt="Pickup QR Code"
                  className={`w-56 h-56 rounded-xl transition-all duration-300 ${
                    qrState === 'expired' ? 'opacity-30 grayscale' : qrState === 'used' ? 'opacity-40 grayscale' : ''
                  }`}
                />
                {qrState === 'expired' && (
                  <div className="absolute inset-0 flex flex-col items-center justify-center bg-white/70 rounded-xl">
                    <span className="text-sm font-bold text-rose-600 uppercase tracking-widest px-3 py-1 bg-rose-100 rounded-lg">
                      EXPIRED
                    </span>
                    <span className="text-[11px] text-slate-600 mt-1">Visit counter for assistance</span>
                  </div>
                )}
                {qrState === 'used' && (
                  <div className="absolute inset-0 flex flex-col items-center justify-center bg-white/70 rounded-xl">
                    <span className="text-sm font-bold text-slate-700 uppercase tracking-widest px-3 py-1 bg-slate-200 rounded-lg">
                      COLLECTED
                    </span>
                  </div>
                )}
              </div>
            ) : (
              <div className="w-56 h-56 flex items-center justify-center">
                <div className="w-8 h-8 border-2 border-indigo-600 border-t-transparent rounded-full animate-spin" />
              </div>
            )}
          </div>

          {/* Bill Identifier */}
          <div className="mt-4 text-center">
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-slate-100 text-slate-800 text-xs font-mono font-bold tracking-wider">
              BILL NO: {bill.bill_no}
            </div>
            <div className="text-xs text-slate-400 mt-1">
              Token: {bill.qr_token || 'Awaiting activation'}
            </div>
          </div>

          {/* Items Summary */}
          <div className="w-full mt-5 pt-4 border-t border-slate-100">
            <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">
              Items in this bill
            </div>
            <div className="space-y-1.5 max-h-36 overflow-y-auto pr-1">
              {bill.items.map((it) => (
                <div key={it.item_id} className="flex justify-between items-center text-xs">
                  <span className="text-slate-800">
                    {it.quantity}x {it.product_name}
                    {it.item_status === 'unavailable_refunded' && (
                      <span className="ml-1 text-rose-600 font-medium">(Unavailable - Refunded)</span>
                    )}
                  </span>
                  <span className="font-mono font-semibold text-slate-900">
                    Rs. {it.price * it.quantity}
                  </span>
                </div>
              ))}
            </div>

            <div className="flex justify-between items-center pt-2 mt-2 border-t border-slate-100 text-sm font-bold text-slate-900">
              <span>Total Paid</span>
              <span className="font-mono text-indigo-700">Rs. {bill.total}</span>
            </div>
          </div>

          {/* Cancel button if still New or Accepted */}
          {(bill.status === 'new' || bill.status === 'accepted') && (
            <div className="w-full mt-4">
              <button
                onClick={() => {
                  if (confirm(`Cancel bill ${bill.bill_no}? You will receive an immediate full refund of Rs. ${bill.total}.`)) {
                    cancelStudentBill(bill.stall_order_id);
                    onClose();
                  }
                }}
                className="w-full py-2.5 px-4 text-xs font-semibold text-rose-600 hover:text-rose-700 bg-rose-50 hover:bg-rose-100 rounded-xl transition-colors border border-rose-200"
              >
                Cancel Bill & Auto Refund (Rs. {bill.total})
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
