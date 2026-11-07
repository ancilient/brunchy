import React, { useState } from 'react';
import { useCanteen } from '../../context/CanteenContext';
import { useAndroidBack, BACK_PRIORITY } from '../../native';
import { X, QrCode, ShieldCheck, Loader2, ArrowRight } from 'lucide-react';

interface PayModalProps {
  isOpen: boolean;
  onClose: () => void;
  onPaymentSuccess: (orderId: number) => void;
}

export const PayModal: React.FC<PayModalProps> = ({
  isOpen,
  onClose,
  onPaymentSuccess,
}) => {
  const { activePendingOrder, completeUpiPayment, cancelCheckoutHold } = useCanteen();
  const [selectedMethod, setSelectedMethod] = useState<'qr' | 'gpay' | 'phonepe' | 'paytm' | 'bhim'>('gpay');
  const [isVerifying, setIsVerifying] = useState<boolean>(false);
  const [showQrDisplay, setShowQrDisplay] = useState<boolean>(false);

  useAndroidBack(() => {
    if (!isOpen || !activePendingOrder) return false;
    if (isVerifying) return true;                       // never interrupt a payment check
    if (showQrDisplay) { setShowQrDisplay(false); return true; }
    cancelCheckoutHold();
    onClose();
    return true;
  }, BACK_PRIORITY.MODAL);

  if (!isOpen || !activePendingOrder) return null;

  const handlePay = async (method: string) => {
    setIsVerifying(true);
    try {
      const res = await completeUpiPayment(method);
      if (res.success && res.orderId) {
        onPaymentSuccess(res.orderId);
      }
    } catch (e) {
      alert('Payment could not be verified. Please retry.');
    } finally {
      setIsVerifying(false);
    }
  };

  const upiApps = [
    { id: 'gpay', name: 'Google Pay', icon: '⚡', color: 'bg-blue-50 text-blue-600 border-blue-200' },
    { id: 'phonepe', name: 'PhonePe', icon: '🟣', color: 'bg-purple-50 text-purple-600 border-purple-200' },
    { id: 'paytm', name: 'Paytm', icon: '🔷', color: 'bg-sky-50 text-sky-600 border-sky-200' },
    { id: 'bhim', name: 'BHIM UPI', icon: '🇮🇳', color: 'bg-emerald-50 text-emerald-600 border-emerald-200' },
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-150">
      <div className="w-full sm:max-w-md bg-white rounded-t-3xl sm:rounded-3xl shadow-2xl border border-slate-100 overflow-hidden p-6 pb-[calc(1.5rem+var(--sab))] animate-in slide-in-from-bottom duration-200">
        <div className="w-12 h-1.5 bg-slate-200 rounded-full mx-auto mb-4 sm:hidden" />

        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-slate-100 mb-4">
          <div>
            <h3 className="text-xl font-bold text-slate-900 font-display">
              Payment
            </h3>
            <p className="text-xs text-slate-500">
              {activePendingOrder.canteen_name} · Total to Pay: <span className="font-bold text-[#E63E11] font-mono">₹{activePendingOrder.total}</span>
            </p>
          </div>
          <button
            onClick={() => {
              cancelCheckoutHold();
              onClose();
            }}
            disabled={isVerifying}
            className="w-9 h-9 flex items-center justify-center rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-100"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {isVerifying ? (
          <div className="py-12 text-center space-y-4">
            <Loader2 className="w-12 h-12 text-[#E63E11] animate-spin mx-auto" />
            <div>
              <h4 className="text-base font-bold text-slate-900">
                Checking payment with bank...
              </h4>
              <p className="text-xs text-slate-500 mt-1 max-w-xs mx-auto">
                Please do not hit back or close the app. Never charged twice.
              </p>
            </div>
          </div>
        ) : showQrDisplay ? (
          <div className="text-center py-4 space-y-4">
            <div className="p-4 bg-slate-50 rounded-2xl inline-block border-2 border-dashed border-amber-300">
              <QrCode className="w-48 h-48 text-slate-900 mx-auto" />
            </div>
            <p className="text-xs text-slate-600 font-medium">
              Scan with any UPI app to pay ₹{activePendingOrder.total}
            </p>
            <button
              onClick={() => handlePay('QR Code')}
              className="w-full py-3 bg-gradient-to-r from-[#FF6E40] to-[#E63E11] text-white rounded-2xl text-xs font-bold shadow-md shadow-orange-500/20"
            >
              Simulate Successful QR Payment
            </button>
            <button
              onClick={() => setShowQrDisplay(false)}
              className="text-xs text-slate-400 hover:text-slate-600 block mx-auto"
            >
              ← Back to UPI App Selection
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            {/* Pay via QR Code option */}
            <button
              onClick={() => setShowQrDisplay(true)}
              className="w-full p-3.5 rounded-2xl border border-amber-200/80 bg-orange-50/40 hover:bg-orange-50 flex items-center justify-between transition-all"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-white border border-amber-200 flex items-center justify-center text-slate-800 shadow-xs">
                  <QrCode className="w-5 h-5 text-[#E63E11]" />
                </div>
                <div className="text-left">
                  <span className="text-xs font-bold text-slate-900 block">
                    Show Payment QR Code
                  </span>
                  <span className="text-[10px] text-slate-500">
                    Scan with any college or banking scanner
                  </span>
                </div>
              </div>
              <ArrowRight className="w-4 h-4 text-[#E63E11]" />
            </button>

            <div className="relative my-2 text-center">
              <span className="bg-white px-3 text-[11px] text-slate-400 uppercase font-semibold">
                Or Tap Your UPI App
              </span>
            </div>

            {/* Tap directly into UPI app icons per PDF */}
            <div className="grid grid-cols-2 gap-2.5">
              {upiApps.map((app) => (
                <button
                  key={app.id}
                  onClick={() => handlePay(app.name)}
                  className={`p-3 rounded-2xl border text-left transition-all flex items-center gap-2.5 hover:shadow-xs active:scale-[0.98] ${app.color}`}
                >
                  <span className="text-xl">{app.icon}</span>
                  <div>
                    <span className="text-xs font-bold block leading-tight text-slate-900">
                      {app.name}
                    </span>
                    <span className="text-[9px] text-slate-500">Instant pay</span>
                  </div>
                </button>
              ))}
            </div>

            <div className="pt-2 flex items-center justify-center gap-1.5 text-[11px] text-slate-400 text-center">
              <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
              <span>100% Secure Campus Gateway · Instant refund if stall rejects</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
