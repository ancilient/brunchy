/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect } from 'react';
import { useAndroidBack, BACK_PRIORITY } from './native';
import { CanteenProvider, useCanteen } from './context/CanteenContext';
import { Header } from './components/common/Header';
import { SplashLogo } from './components/student/SplashLogo';
import { LoginScreen } from './components/student/LoginScreen';
import { ChooseCanteenScreen } from './components/student/ChooseCanteenScreen';
import { StudentHome } from './components/student/StudentHome';
import { CartScreen } from './components/student/CartScreen';
import { PayModal } from './components/student/PayModal';
import { OrdersPage } from './components/student/OrdersPage';
import { ProfilePage } from './components/student/ProfilePage';
import { CheckoutShortageModal } from './components/student/CheckoutShortageModal';
import { CanteenSelectorModal } from './components/student/CanteenSelectorModal';
import { Home, ShoppingBag, FileText, User } from 'lucide-react';

const StudentAppShell: React.FC = () => {
  const {
    currentUser,
    hasActiveOrder,
    cart,
    getStudentBills,
    startCheckout,
    cancelCheckoutHold,
    stockShortages,
    activePendingOrder,
    holdExpiredCount,
  } = useCanteen();

  // Navigation within Student app: 'home' | 'cart' | 'orders' | 'profile'
  const [activeTab, setActiveTab] = useState<'home' | 'cart' | 'orders' | 'profile'>(() => {
    // If student has active order, open straight to Orders page per flow specification
    return hasActiveOrder ? 'orders' : 'home';
  });

  // Screen control: splash -> login -> choose_canteen -> app
  const [showSplash, setShowSplash] = useState<boolean>(true);
  const [hasChosenCanteen, setHasChosenCanteen] = useState<boolean>(() => {
    // If active order exists, skip choose canteen
    return hasActiveOrder;
  });
  const [isPayModalOpen, setIsPayModalOpen] = useState<boolean>(false);
  const [isCanteenPickerModalOpen, setIsCanteenPickerModalOpen] = useState<boolean>(false);
  const [retryCheckout, setRetryCheckout] = useState<boolean>(false);

  // After the student resolves a stock shortage, run checkout again with the corrected cart.
  useEffect(() => {
    if (!retryCheckout) return;
    setRetryCheckout(false);
    if (cart.length === 0) return;
    const res = startCheckout();
    if (res.success) setIsPayModalOpen(true);
    else if (res.message) alert(res.message);
  }, [retryCheckout, cart]);

  // The 5-minute payment hold ran out: close the payment sheet and say why.
  useEffect(() => {
    if (holdExpiredCount === 0) return;
    setIsPayModalOpen(false);
    alert('Payment time ran out, so your items were released. Please tap Pay again.');
  }, [holdExpiredCount]);

  // Android back button: popups handle it first (they register with a higher priority);
  // here, any tab other than Home goes back to Home, and on Home the app is minimised.
  const inMainApp = !showSplash && currentUser.is_logged_in && (hasChosenCanteen || hasActiveOrder);
  useAndroidBack(() => {
    if (showSplash) return true;
    if (!inMainApp) return false;
    if (isPayModalOpen && activePendingOrder) return false;   // PayModal handles it
    if (activeTab !== 'home') { setActiveTab('home'); return true; }
    return false;
  }, BACK_PRIORITY.SHELL);

  // Sync tab if new active order arrives
  useEffect(() => {
    if (hasActiveOrder && activeTab === 'home' && !hasChosenCanteen) {
      setActiveTab('orders');
      setHasChosenCanteen(true);
    }
  }, [hasActiveOrder]);

  const cartItemCount = cart.reduce((sum, item) => sum + item.quantity, 0);
  const activeOrdersCount = getStudentBills().filter(
    (b) => b.status === 'waiting_for_acceptance' || b.status === 'accepted' || b.status === 'ready'
  ).length;

  if (showSplash) {
    return <SplashLogo onFinish={() => setShowSplash(false)} />;
  }

  // First time login
  if (!currentUser.is_logged_in) {
    return <LoginScreen onLoginSuccess={() => setHasChosenCanteen(false)} />;
  }

  // Choose Canteen (shows every time app opens when NO active order)
  if (!hasChosenCanteen && !hasActiveOrder) {
    return (
      <ChooseCanteenScreen
        onCanteenChosen={() => {
          setHasChosenCanteen(true);
          setActiveTab('home');
        }}
      />
    );
  }

  return (
    <div className="min-h-screen bg-[#FAF2E4] flex flex-col justify-between">
      {/* Scrollable Student Content */}
      <div className="flex-1">
        {activeTab === 'home' && (
          <StudentHome
            onOpenCart={() => setActiveTab('cart')}
            onOpenCanteenPicker={() => setIsCanteenPickerModalOpen(true)}
            onViewOrders={() => setActiveTab('orders')}
          />
        )}

        {activeTab === 'cart' && (
          <CartScreen
            onBackToMenu={() => setActiveTab('home')}
            onProceedToPay={() => setIsPayModalOpen(true)}
            onShortageDetected={() => {}}
          />
        )}

        {activeTab === 'orders' && (
          <OrdersPage onBackToMenu={() => setActiveTab('home')} />
        )}

        {activeTab === 'profile' && (
          <ProfilePage
            onSwitchCanteen={() => setIsCanteenPickerModalOpen(true)}
            onReorder={() => setActiveTab('cart')}
          />
        )}
      </div>

      {/* Floating Bottom Navigation Bar matching client mockup */}
      <div className="fixed bottom-0 inset-x-0 z-40 bg-white/95 backdrop-blur-md border-t border-amber-200/60 shadow-lg pt-2 pb-[calc(0.5rem+var(--sab))]">
        <div className="max-w-md mx-auto grid grid-cols-4 px-2">
          {/* Tab 1: Home */}
          <button
            onClick={() => setActiveTab('home')}
            className={`flex flex-col items-center py-1 transition-all ${
              activeTab === 'home' ? 'text-[#E63E11] font-bold' : 'text-slate-500 hover:text-slate-900'
            }`}
          >
            <div className={`p-1 rounded-xl ${activeTab === 'home' ? 'bg-orange-100 text-[#E63E11]' : ''}`}>
              <Home className="w-5 h-5" />
            </div>
            <span className="text-[10px] mt-0.5">Home</span>
          </button>

          {/* Tab 2: Cart */}
          <button
            onClick={() => setActiveTab('cart')}
            className={`relative flex flex-col items-center py-1 transition-all ${
              activeTab === 'cart' ? 'text-[#E63E11] font-bold' : 'text-slate-500 hover:text-slate-900'
            }`}
          >
            <div className={`p-1 rounded-xl ${activeTab === 'cart' ? 'bg-orange-100 text-[#E63E11]' : ''}`}>
              <ShoppingBag className="w-5 h-5" />
            </div>
            <span className="text-[10px] mt-0.5">Cart</span>
            {cartItemCount > 0 && (
              <span className="absolute top-0.5 right-6 w-4 h-4 bg-[#E63E11] text-white rounded-full text-[9px] font-bold flex items-center justify-center font-mono">
                {cartItemCount}
              </span>
            )}
          </button>

          {/* Tab 3: Orders */}
          <button
            onClick={() => setActiveTab('orders')}
            className={`relative flex flex-col items-center py-1 transition-all ${
              activeTab === 'orders' ? 'text-[#E63E11] font-bold' : 'text-slate-500 hover:text-slate-900'
            }`}
          >
            <div className={`p-1 rounded-xl ${activeTab === 'orders' ? 'bg-orange-100 text-[#E63E11]' : ''}`}>
              <FileText className="w-5 h-5" />
            </div>
            <span className="text-[10px] mt-0.5">Orders</span>
            {activeOrdersCount > 0 && (
              <span className="absolute top-0.5 right-5 w-4 h-4 bg-emerald-600 text-white rounded-full text-[9px] font-bold flex items-center justify-center font-mono animate-pulse">
                {activeOrdersCount}
              </span>
            )}
          </button>

          {/* Tab 4: Profile */}
          <button
            onClick={() => setActiveTab('profile')}
            className={`flex flex-col items-center py-1 transition-all ${
              activeTab === 'profile' ? 'text-[#E63E11] font-bold' : 'text-slate-500 hover:text-slate-900'
            }`}
          >
            <div className={`p-1 rounded-xl ${activeTab === 'profile' ? 'bg-orange-100 text-[#E63E11]' : ''}`}>
              <User className="w-5 h-5" />
            </div>
            <span className="text-[10px] mt-0.5">Profile</span>
          </button>
        </div>
      </div>

      {/* Pay Modal */}
      <PayModal
        isOpen={isPayModalOpen}
        onClose={() => setIsPayModalOpen(false)}
        onPaymentSuccess={() => {
          setIsPayModalOpen(false);
          setActiveTab('orders');
        }}
      />

      {/* Canteen Switcher Modal */}
      <CanteenSelectorModal
        isOpen={isCanteenPickerModalOpen}
        onClose={() => setIsCanteenPickerModalOpen(false)}
      />

      {/* Stock shortage prompt */}
      <CheckoutShortageModal
        onSuccessProceed={() => setRetryCheckout(true)}
      />
    </div>
  );
};

const MainAppContent: React.FC = () => {
  const [showSplashOverlay, setShowSplashOverlay] = useState<boolean>(false);

  return (
    <div className="min-h-screen bg-[#FAF2E4] text-slate-900 flex flex-col font-sans">
      {/* Top Header with Demo Clock & Logo Replay */}
      <Header
        onReplaySplash={() => setShowSplashOverlay(true)}
      />

      {showSplashOverlay && (
        <SplashLogo onFinish={() => setShowSplashOverlay(false)} />
      )}

      {/* Student App Only */}
      <main className="flex-1">
        <StudentAppShell />
      </main>
    </div>
  );
};

export default function App() {
  return (
    <CanteenProvider>
      <MainAppContent />
    </CanteenProvider>
  );
}

