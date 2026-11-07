import React from 'react';
import { useCanteen } from '../../context/CanteenContext';
import { useAndroidBack, BACK_PRIORITY } from '../../native';
import { AlertCircle } from 'lucide-react';

interface CheckoutShortageModalProps {
  onSuccessProceed: () => void;
}

export const CheckoutShortageModal: React.FC<CheckoutShortageModalProps> = ({ onSuccessProceed }) => {
  const { stockShortages, handleShortageChoice, clearShortages } = useCanteen();

  useAndroidBack(() => {
    if (stockShortages.length === 0) return false;
    clearShortages();
    return true;
  }, BACK_PRIORITY.MODAL);

  if (stockShortages.length === 0) return null;

  const currentShortage = stockShortages[0];

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-150">
      <div className="w-full sm:max-w-md bg-white rounded-t-3xl sm:rounded-3xl shadow-2xl border border-slate-100 overflow-hidden p-6 pb-[calc(1.5rem+var(--sab))] animate-in slide-in-from-bottom duration-200">
        <div className="w-12 h-1.5 bg-slate-200 rounded-full mx-auto mb-4 sm:hidden" />

        <div className="flex items-center gap-3 text-amber-600 mb-3">
          <div className="w-10 h-10 rounded-full bg-amber-50 flex items-center justify-center shrink-0">
            <AlertCircle className="w-6 h-6 text-amber-600" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-slate-900 font-display">
              Limited Stock Alert
            </h3>
            <p className="text-xs text-slate-500">
              High rush at the canteen counter
            </p>
          </div>
        </div>

        <div className="p-4 bg-amber-50/70 border border-amber-200/70 rounded-2xl my-4 text-sm text-slate-800">
          <p className="font-semibold text-slate-900 text-base">
            Only {currentShortage.available} {currentShortage.product.product_name} left
          </p>
          <p className="text-xs text-slate-600 mt-1">
            You asked for {currentShortage.requested}. Would you like to order {currentShortage.available} instead?
          </p>
          <p className="text-[11px] text-slate-500 mt-2 font-medium">
            Nothing has been charged yet. Your payment amount will adjust automatically.
          </p>
        </div>

        <div className="flex gap-3 mt-6">
          <button
            onClick={() => {
              handleShortageChoice(currentShortage.product.product_id, false);
              if (stockShortages.length <= 1) {
                clearShortages();
                onSuccessProceed();
              }
            }}
            className="flex-1 py-3 px-4 rounded-xl border border-slate-300 text-slate-700 font-semibold text-xs hover:bg-slate-50 transition-colors"
          >
            Remove Item
          </button>

          {currentShortage.available > 0 && (
            <button
              onClick={() => {
                handleShortageChoice(currentShortage.product.product_id, true);
                if (stockShortages.length <= 1) {
                  clearShortages();
                  onSuccessProceed();
                }
              }}
              className="flex-1 py-3 px-4 rounded-xl bg-[#3A3D9E] text-white font-semibold text-xs hover:bg-indigo-700 transition-colors shadow-md shadow-indigo-500/20"
            >
              Order {currentShortage.available}
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
