import React, { useState } from 'react';
import { useAndroidBack, BACK_PRIORITY } from '../../native';
import { X, Phone, MessageSquare, AlertCircle, ShieldCheck, Check } from 'lucide-react';

interface CustomerCareModalProps {
  onClose: () => void;
}

export const CustomerCareModal: React.FC<CustomerCareModalProps> = ({ onClose }) => {
  const [complaintSubmitted, setComplaintSubmitted] = useState<boolean>(false);
  const [issueText, setIssueText] = useState<string>('');

  useAndroidBack(() => { onClose(); return true; }, BACK_PRIORITY.MODAL);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!issueText.trim()) return;
    setComplaintSubmitted(true);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-150">
      <div className="w-full max-w-sm bg-white rounded-3xl p-6 shadow-2xl border border-slate-100">
        <div className="flex items-center justify-between pb-3 border-b border-slate-100 mb-4">
          <div className="flex items-center gap-2 text-slate-900 font-bold font-display">
            <div className="w-8 h-8 rounded-xl bg-orange-100 text-[#E63E11] flex items-center justify-center">
              <Phone className="w-4 h-4" />
            </div>
            <span>Brunchy Customer Care</span>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center text-slate-400 hover:text-slate-700"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {complaintSubmitted ? (
          <div className="py-8 text-center space-y-3">
            <div className="w-12 h-12 rounded-full bg-emerald-100 text-emerald-700 flex items-center justify-center mx-auto">
              <Check className="w-6 h-6 stroke-[3]" />
            </div>
            <h4 className="text-base font-bold text-slate-900">Ticket #CC-8821 Created</h4>
            <p className="text-xs text-slate-500">
              Our campus canteen manager has been notified. We will resolve your query within 3 minutes!
            </p>
            <button
              onClick={onClose}
              className="mt-4 px-6 py-2.5 bg-[#E63E11] text-white rounded-xl text-xs font-bold"
            >
              Done
            </button>
          </div>
        ) : (
          <div className="space-y-4 text-xs">
            {/* Quick Contacts */}
            <div className="p-3 bg-orange-50 rounded-2xl border border-orange-200/60 space-y-2">
              <span className="font-bold text-[#E63E11] block">Emergency Canteen Helplines</span>
              <div className="flex justify-between items-center text-slate-700">
                <span>Main Canteen Desk:</span>
                <span className="font-mono font-bold">+91 98450 00111</span>
              </div>
              <div className="flex justify-between items-center text-slate-700">
                <span>Advance Block Desk:</span>
                <span className="font-mono font-bold">+91 98450 00222</span>
              </div>
            </div>

            {/* Instant Report Form */}
            <form onSubmit={handleSubmit} className="space-y-3">
              <label className="font-semibold text-slate-700 block">
                Have an issue with your order or payment?
              </label>
              <textarea
                required
                value={issueText}
                onChange={(e) => setIssueText(e.target.value)}
                placeholder="e.g. UPI deducted but order delayed, or stall didn't have cheese..."
                rows={3}
                className="w-full p-3 rounded-2xl border border-slate-200 text-xs focus:ring-2 focus:ring-[#FF6E40] focus:outline-none"
              />
              <button
                type="submit"
                className="w-full py-3 bg-[#E63E11] hover:bg-[#d63408] text-white rounded-2xl font-bold transition-colors shadow-md shadow-orange-500/20"
              >
                Send Message to Help Desk
              </button>
            </form>

            <div className="pt-2 text-[10px] text-slate-400 text-center flex items-center justify-center gap-1">
              <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
              <span>Refund queries are automatically credited to your UPI ID</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
