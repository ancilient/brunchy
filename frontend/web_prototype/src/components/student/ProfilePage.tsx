import React, { useState } from 'react';
import { useCanteen } from '../../context/CanteenContext';
import {
  User,
  Phone,
  Award,
  RefreshCw,
  Clock,
  RotateCcw,
  FileText,
  Shield,
  HelpCircle,
  LogOut,
  ChevronRight,
  Sparkles
} from 'lucide-react';
import { CustomerCareModal } from './CustomerCareModal';
import { useAndroidBack, BACK_PRIORITY } from '../../native';

interface ProfilePageProps {
  onSwitchCanteen: () => void;
  onReorder: () => void;
}

export const ProfilePage: React.FC<ProfilePageProps> = ({
  onSwitchCanteen,
  onReorder,
}) => {
  const { currentUser, canteens, selectedCanteenId, setSelectedCanteenId, cart, orders, addToCart, products, logoutStudent } = useCanteen();
  const [showPolicyModal, setShowPolicyModal] = useState<'terms' | 'privacy' | 'refund' | null>(null);
  const [showCustomerCare, setShowCustomerCare] = useState<boolean>(false);

  useAndroidBack(() => {
    if (!showPolicyModal) return false;
    setShowPolicyModal(null);
    return true;
  }, BACK_PRIORITY.MODAL);

  const currentCanteen = canteens.find((c) => c.canteen_id === selectedCanteenId) || canteens[0];

  const pastOrders = orders
    .filter((o) => o.status === 'paid' && o.user_id === currentUser.user_id)
    .slice(0, 5);

  const handleReorderClick = (order: typeof orders[0]) => {
    // Add items from this order into the current cart; count only what was really added
    let addedCount = 0;
    let firstProblem = '';
    if (cart.length > 0 && cart[0].product.canteen_id !== order.canteen_id) {
      alert(`Your cart has items from another canteen. Clear it first to reorder from ${order.canteen_name}.`);
      return;
    }
    if (order.canteen_id !== selectedCanteenId) setSelectedCanteenId(order.canteen_id);
    order.bills.forEach((bill) => {
      bill.items.forEach((it) => {
        if (it.item_status === 'unavailable_refunded') return;
        const prod = products.find((p) => p.product_id === it.product_id);
        if (!prod || !prod.is_active || prod.approval_status !== 'published') {
          firstProblem ||= `${it.product_name} is no longer on the menu.`;
          return;
        }
        const qty = Math.min(it.quantity, prod.stock_quantity);
        if (qty <= 0) {
          firstProblem ||= `${it.product_name} is sold out.`;
          return;
        }
        const res = addToCart(prod, qty);
        if (res.success) addedCount++;
        else firstProblem ||= res.reason || `${it.product_name} could not be added.`;
      });
    });

    if (addedCount > 0) {
      alert(firstProblem ? `Items added to your cart. Note: ${firstProblem}` : 'Items added to your cart!');
      onReorder();
    } else {
      alert(firstProblem || 'Items from this order are currently out of stock.');
    }
  };

  return (
    <div className="w-full max-w-md mx-auto px-4 pt-3 pb-28 space-y-5 text-xs">
      {/* Profile Header Card */}
      <div className="bg-white rounded-3xl p-5 border border-amber-200/80 shadow-sm flex items-center justify-between">
        <div className="flex items-center gap-3.5">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#FF6E40] to-[#E63E11] text-white flex items-center justify-center font-bold text-lg font-display shadow-md shadow-orange-500/20">
            {currentUser.name.charAt(0)}
          </div>
          <div>
            <h3 className="text-base font-bold text-slate-900 font-display">
              {currentUser.name}
            </h3>
            <p className="text-slate-500 font-mono text-[11px] mt-0.5">
              +91 {currentUser.phone}
            </p>
            {currentUser.register_no && (
              <span className="inline-block mt-1 bg-amber-50 text-amber-800 text-[10px] font-semibold px-2 py-0.5 rounded-md font-mono">
                Reg: {currentUser.register_no}
              </span>
            )}
          </div>
        </div>

        <button
          onClick={logoutStudent}
          className="text-slate-400 hover:text-rose-600 transition-colors p-2"
          title="Sign out / Switch account"
        >
          <LogOut className="w-4 h-4" />
        </button>
      </div>

      {/* Switch Canteen Button */}
      <div className="bg-white rounded-3xl p-4 border border-amber-200/80 shadow-xs flex items-center justify-between">
        <div>
          <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400 block">
            Current Active Canteen:
          </span>
          <span className="text-sm font-bold text-slate-900 font-display">
            {currentCanteen.canteen_name}
          </span>
        </div>
        <button
          onClick={onSwitchCanteen}
          className="px-3.5 py-2 rounded-2xl bg-orange-50 hover:bg-orange-100 text-[#E63E11] font-bold text-xs border border-orange-200/80 transition-colors"
        >
          Switch Canteen
        </button>
      </div>

      {/* Past Orders with Reorder Button per PDF */}
      <div className="bg-white rounded-3xl p-5 border border-amber-200/80 shadow-sm space-y-3">
        <div className="flex items-center justify-between pb-2 border-b border-slate-100">
          <h4 className="text-sm font-bold text-slate-900 font-display">
            Past Orders & Fast Reorder
          </h4>
          <span className="text-[11px] text-slate-400">{pastOrders.length} previous</span>
        </div>

        {pastOrders.length === 0 ? (
          <p className="text-slate-400 py-3 text-center">No past orders yet.</p>
        ) : (
          <div className="space-y-3">
            {pastOrders.map((ord) => (
              <div
                key={ord.order_id}
                className="p-3 bg-slate-50/70 rounded-2xl border border-slate-200/60 flex items-center justify-between gap-3"
              >
                <div>
                  <span className="font-bold text-slate-900 block">
                    {ord.bills.flatMap((b) => b.items.map((i) => `${i.quantity}x ${i.product_name}`)).join(', ')}
                  </span>
                  <span className="text-[10px] text-slate-400">
                    {new Date(ord.created_at).toLocaleDateString([], { month: 'short', day: 'numeric' })} · ₹{ord.total}
                  </span>
                </div>

                <button
                  onClick={() => handleReorderClick(ord)}
                  className="px-3 py-1.5 bg-white hover:bg-orange-50 text-[#E63E11] font-bold rounded-xl border border-orange-200 shadow-2xs flex items-center gap-1 shrink-0"
                >
                  <RotateCcw className="w-3 h-3" />
                  <span>Reorder</span>
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Help & Policies (Terms, Privacy, Refund policy for payment gateway) */}
      <div className="bg-white rounded-3xl p-5 border border-amber-200/80 shadow-sm space-y-3">
        <h4 className="text-sm font-bold text-slate-900 font-display mb-2">
          Help & Legal Policies
        </h4>

        <button
          onClick={() => setShowCustomerCare(true)}
          className="w-full flex items-center justify-between py-2 text-slate-700 hover:text-slate-900 border-b border-slate-100"
        >
          <div className="flex items-center gap-2.5">
            <HelpCircle className="w-4 h-4 text-orange-500" />
            <span>Campus Help Desk & Customer Care</span>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400" />
        </button>

        <button
          onClick={() => setShowPolicyModal('refund')}
          className="w-full flex items-center justify-between py-2 text-slate-700 hover:text-slate-900 border-b border-slate-100"
        >
          <div className="flex items-center gap-2.5">
            <RefreshCw className="w-4 h-4 text-emerald-500" />
            <span>Refund & Cancellation Policy</span>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400" />
        </button>

        <button
          onClick={() => setShowPolicyModal('terms')}
          className="w-full flex items-center justify-between py-2 text-slate-700 hover:text-slate-900 border-b border-slate-100"
        >
          <div className="flex items-center gap-2.5">
            <FileText className="w-4 h-4 text-blue-500" />
            <span>Terms of Service</span>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400" />
        </button>

        <button
          onClick={() => setShowPolicyModal('privacy')}
          className="w-full flex items-center justify-between py-2 text-slate-700 hover:text-slate-900"
        >
          <div className="flex items-center gap-2.5">
            <Shield className="w-4 h-4 text-purple-500" />
            <span>Privacy Policy (DPDP Act 2023 Compliant)</span>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400" />
        </button>
      </div>

      {/* Policy Modal */}
      {showPolicyModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div className="bg-white rounded-3xl p-6 max-w-sm w-full shadow-2xl border border-slate-100">
            <h3 className="text-base font-bold text-slate-900 font-display mb-2 capitalize">
              {showPolicyModal} Policy
            </h3>
            <div className="text-xs text-slate-600 space-y-2 max-h-60 overflow-y-auto pr-1">
              {showPolicyModal === 'refund' && (
                <>
                  <p>
                    1. <strong>Full Refund Before Cooking:</strong> Orders cancelled while in 'Waiting for Acceptance' or 'Accepted' before kitchen cooking begins are credited 100% to your original payment UPI handle.
                  </p>
                  <p>
                    2. <strong>Out-of-Stock Items:</strong> If a specific item runs out, it is refunded immediately while the remaining bill items continue.
                  </p>
                  <p>
                    3. <strong>Stall Emergencies:</strong> All unfulfilled orders are automatically refunded within 24 hours via gateway route.
                  </p>
                </>
              )}
              {showPolicyModal === 'terms' && (
                <>
                  <p>
                    Brunchy is the campus food ordering technology platform providing real-time menu browsing and queue-free counter collections.
                  </p>
                  <p>
                    Students are expected to collect food within the designated preparation window by presenting their 3-digit pickup code.
                  </p>
                </>
              )}
              {showPolicyModal === 'privacy' && (
                <>
                  <p>
                    We collect student name, mobile number, and optional registration number strictly for token verification and SMS pickup notifications.
                  </p>
                  <p>
                    We never store GPS coordinates or payment credentials on our servers.
                  </p>
                </>
              )}
            </div>
            <button
              onClick={() => setShowPolicyModal(null)}
              className="w-full mt-4 py-2.5 bg-[#E63E11] text-white rounded-xl font-bold"
            >
              Close
            </button>
          </div>
        </div>
      )}

      {showCustomerCare && (
        <CustomerCareModal onClose={() => setShowCustomerCare(false)} />
      )}
    </div>
  );
};
