import React, { useState } from 'react';
import { useCanteen } from '../../context/CanteenContext';
import { X, Clock, ShieldCheck, Check, Smartphone, ArrowRight, Loader2 } from 'lucide-react';

interface UpiPaymentModalProps {
  isOpen: boolean;
  onClose: () => void;
  onPaymentSuccess: (orderId: number) => void;
}

export const UpiPaymentModal: React.FC<UpiPaymentModalProps> = ({
  isOpen,
  onClose,
  onPaymentSuccess,
}) => {
  const {
    activePendingOrder,
    holdSecondsLeft,
    completeUpiPayment,
    cancelCheckoutHold,
  } = useCanteen();

  const [selectedApp, setSelectedApp] = useState<string>('Google Pay');
  const [isProcessing, setIsProcessing] = useState<boolean>(false);
  const [errorMessage, setErrorMessage] = useState<string>('');

  if (!isOpen || !activePendingOrder) return null;

  const formatHoldTimer = (sec: number) => {
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  };

  const upiApps = [
    { id: 'gpay', name: 'Google Pay', icon: '⚡', color: 'text-blue-600 bg-blue-50' },
    { id: 'phonepe', name: 'PhonePe', icon: '🟣', color: 'text-purple-600 bg-purple-50' },
    { id: 'paytm', name: 'Paytm', icon: '🔷', color: 'text-sky-600 bg-sky-50' },
    { id: 'bhim', name: 'BHIM / any other UPI app', icon: '🇮🇳', color: 'text-emerald-600 bg-emerald-50' },
  ];

  const handlePay = async () => {
    if (isProcessing) return; // Prevent double taps per section 4.5
    setIsProcessing(true);
    setErrorMessage('');

    try {
      const res = await completeUpiPayment(selectedApp);
      if (res.success && res.orderId) {
        onPaymentSuccess(res.orderId);
      } else {
        setErrorMessage('Payment simulation encountered an error. Please retry.');
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'Payment failed');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleCancel = () => {
    cancelCheckoutHold();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-150">
      <div className="w-full sm:max-w-md bg-white rounded-t-3xl sm:rounded-3xl shadow-2xl border border-slate-100 overflow-hidden p-6 pb-[calc(1.5rem+var(--sab))] animate-in slide-in-from-bottom duration-200">
        <div className="w-12 h-1.5 bg-slate-200 rounded-full mx-auto mb-4 sm:hidden" />

        {/* Top Header */}
        <div className="flex items-center justify-between pb-4 border-b border-slate-100">
          <div>
            <h3 className="text-xl font-bold text-slate-900 font-display">Pay with UPI</h3>
            <p className="text-xs text-slate-500">{activePendingOrder.canteen_name}</p>
          </div>
          <button
            onClick={handleCancel}
            disabled={isProcessing}
            className="w-9 h-9 flex items-center justify-center rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* 5-minute stock hold countdown */}
        <div className="mt-4 p-3 bg-amber-50 border border-amber-200/80 rounded-2xl flex items-center justify-between">
          <div className="flex items-center gap-2 text-xs font-medium text-amber-800">
            <Clock className="w-4 h-4 text-amber-600 animate-pulse" />
            <span>Your items are held for:</span>
          </div>
          <div className="text-sm font-bold font-mono text-amber-900 px-2 py-0.5 bg-white/80 rounded-lg">
            {formatHoldTimer(holdSecondsLeft)}
          </div>
        </div>

        {/* Amount to pay */}
        <div className="my-5 p-4 rounded-2xl bg-slate-50 border border-slate-200/80 flex items-center justify-between">
          <div>
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Total Amount to Pay
            </span>
            <div className="text-2xl font-bold font-mono text-slate-900 mt-0.5">
              Rs. {activePendingOrder.total}
            </div>
          </div>
          <div className="text-right text-xs text-slate-500">
            <div>{activePendingOrder.bills.length} stall bills included</div>
            <div className="text-[11px] text-emerald-600 font-medium">No gateway fee for students</div>
          </div>
        </div>

        {/* UPI Apps selection */}
        <div className="space-y-2">
          <label className="text-xs font-semibold uppercase tracking-wider text-slate-500 block mb-1">
            Choose your UPI app
          </label>
          {upiApps.map((app) => {
            const isSelected = selectedApp === app.name;
            return (
              <div
                key={app.id}
                onClick={() => !isProcessing && setSelectedApp(app.name)}
                className={`flex items-center justify-between p-3 rounded-xl border cursor-pointer transition-all ${
                  isSelected
                    ? 'border-[#3A3D9E] bg-indigo-50/40 text-slate-900 shadow-sm'
                    : 'border-slate-200 hover:border-slate-300 text-slate-700 bg-white'
                }`}
              >
                <div className="flex items-center gap-3">
                  <div className={`w-8 h-8 rounded-lg flex items-center justify-center text-sm ${app.color}`}>
                    {app.icon}
                  </div>
                  <span className="text-sm font-semibold">{app.name}</span>
                </div>
                <div
                  className={`w-5 h-5 rounded-full border flex items-center justify-center transition-all ${
                    isSelected
                      ? 'border-[#3A3D9E] bg-[#3A3D9E] text-white'
                      : 'border-slate-300 bg-white'
                  }`}
                >
                  {isSelected && <Check className="w-3 h-3 stroke-[3]" />}
                </div>
              </div>
            );
          })}
        </div>

        {errorMessage && (
          <div className="mt-3 p-3 bg-rose-50 border border-rose-200 text-rose-700 text-xs rounded-xl">
            {errorMessage}
          </div>
        )}

        {/* Primary CTA Button */}
        <div className="mt-6 space-y-3">
          <button
            onClick={handlePay}
            disabled={isProcessing}
            className="w-full h-12 bg-[#3A3D9E] hover:bg-indigo-700 text-white rounded-xl text-sm font-bold flex items-center justify-center gap-2 shadow-lg shadow-indigo-600/20 active:scale-[0.98] transition-all disabled:opacity-60"
          >
            {isProcessing ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Simulating Webhook Confirmation...</span>
              </>
            ) : (
              <>
                <span>Pay Rs. {activePendingOrder.total}</span>
                <ArrowRight className="w-4 h-4" />
              </>
            )}
          </button>

          <div className="text-center">
            <div className="flex items-center justify-center gap-1.5 text-[11px] text-slate-500">
              <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
              <span>Confirmed automatically by server webhook. Double taps blocked.</span>
            </div>
            <p className="text-[10px] text-slate-400 mt-1">
              Cancellation permitted before stall starts cooking. 5+3 min pickup window upon Ready.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};
