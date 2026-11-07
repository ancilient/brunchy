import React, { useEffect, useState } from 'react';
import { useCanteen } from '../../context/CanteenContext';
import { Product } from '../../types/canteen';
import {
  Search,
  Plus,
  Minus,
  Store,
  ChevronDown,
  Sparkles,
  ShoppingBag
} from 'lucide-react';

interface StudentHomeProps {
  onOpenCart: () => void;
  onOpenCanteenPicker: () => void;
  onViewOrders: () => void;
}

export const StudentHome: React.FC<StudentHomeProps> = ({
  onOpenCart,
  onOpenCanteenPicker,
  onViewOrders,
}) => {
  const {
    canteens,
    stalls,
    products,
    selectedCanteenId,
    cart,
    addToCart,
    updateCartQuantity,
    getStudentBills,
  } = useCanteen();

  const [selectedStallTab, setSelectedStallTab] = useState<number | 'all'>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 15000);
    return () => clearInterval(id);
  }, []);

  const currentCanteen = canteens.find((c) => c.canteen_id === selectedCanteenId) || canteens[0];
  const canteenStalls = stalls.filter((s) => s.canteen_id === selectedCanteenId);

  const cartItemCount = cart.reduce((sum, item) => sum + item.quantity, 0);
  const cartTotalAmount = cart.reduce((sum, item) => sum + item.product.price * item.quantity, 0);

  // Filter products
  const displayProducts = products.filter((p) => {
    if (p.canteen_id !== selectedCanteenId) return false;
    if (p.approval_status !== 'published' || !p.is_active) return false;
    if (selectedStallTab !== 'all' && p.stall_id !== selectedStallTab) return false;
    if (searchQuery.trim()) {
      return (
        p.product_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        p.category.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }
    return true;
  });

  // Food icon renderer for claymorphic cards
  const getFoodVisual = (product: Product) => {
    const name = product.product_name.toLowerCase();
    if (name.includes('burger')) {
      return (
        <span className="text-3xl filter drop-shadow-sm select-none" role="img" aria-label="burger">
          🍔
        </span>
      );
    }
    if (name.includes('fries')) {
      return (
        <span className="text-3xl filter drop-shadow-sm select-none" role="img" aria-label="fries">
          🍟
        </span>
      );
    }
    if (name.includes('juice') || name.includes('shake') || name.includes('coffee')) {
      return (
        <span className="text-3xl filter drop-shadow-sm select-none" role="img" aria-label="drink">
          🧃
        </span>
      );
    }
    if (name.includes('parotta') || name.includes('dosa') || name.includes('thali')) {
      return (
        <span className="text-3xl filter drop-shadow-sm select-none" role="img" aria-label="bread">
          🫓
        </span>
      );
    }
    if (name.includes('tea') || name.includes('chai')) {
      return (
        <span className="text-3xl filter drop-shadow-sm select-none" role="img" aria-label="tea">
          ☕
        </span>
      );
    }
    return (
      <span className="text-3xl filter drop-shadow-sm select-none" role="img" aria-label="snack">
        🥪
      </span>
    );
  };

  return (
    <div className="w-full max-w-md mx-auto px-4 pt-3 pb-28">
      {/* Top Mobile Status Header */}
      <div className="flex items-center justify-between text-xs text-slate-500 mb-3 px-1">
        <span className="font-semibold text-slate-800 font-mono">
          {now.toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit', hour12: true })}
        </span>
        <button
          onClick={onOpenCanteenPicker}
          className="flex items-center gap-1 font-bold text-[#E63E11] bg-orange-50 px-2.5 py-1 rounded-full border border-orange-200/60"
        >
          <span>{currentCanteen.canteen_name}</span>
          <ChevronDown className="w-3 h-3" />
        </button>
      </div>

      {/* Search Input */}
      <div className="relative mb-5">
        <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Search burger, juice, fries, snacks..."
          className="w-full h-11 pl-10 pr-4 rounded-2xl bg-white border border-amber-200/80 text-xs text-slate-800 placeholder-slate-400 shadow-sm focus:ring-2 focus:ring-[#FF6E40] focus:outline-none"
        />
        {searchQuery && (
          <button
            onClick={() => setSearchQuery('')}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] font-bold text-slate-400 hover:text-slate-600"
          >
            Clear
          </button>
        )}
      </div>

      {/* Stall Horizontal Tabs */}
      {!searchQuery && (
        <div className="flex items-center gap-2 overflow-x-auto pb-3 mb-4 scrollbar-none">
          <button
            onClick={() => setSelectedStallTab('all')}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all ${
              selectedStallTab === 'all'
                ? 'bg-gradient-to-r from-[#FF6E40] to-[#E63E11] text-white shadow-sm'
                : 'bg-white text-slate-700 border border-amber-200/60'
            }`}
          >
            All Items
          </button>

          {canteenStalls.map((st) => (
            <button
              key={st.stall_id}
              onClick={() => setSelectedStallTab(st.stall_id)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
                selectedStallTab === st.stall_id
                  ? 'bg-gradient-to-r from-[#FF6E40] to-[#E63E11] text-white shadow-sm'
                  : 'bg-white text-slate-700 border border-amber-200/60'
              }`}
            >
              {st.stall_name}
            </button>
          ))}
        </div>
      )}

      {/* Food Cards Grid - Matches exact WhatsApp screenshot aesthetic! */}
      <div className="space-y-6">
        {canteenStalls
          .filter((st) => selectedStallTab === 'all' || st.stall_id === selectedStallTab)
          .map((stall) => {
            const stallProducts = displayProducts.filter((p) => p.stall_id === stall.stall_id);
            if (stallProducts.length === 0) return null;

            return (
              <div key={stall.stall_id} className="space-y-3">
                {/* Stall Divider (e.g. "Juice Corner • OPEN") */}
                <div className="flex items-center justify-between px-1">
                  <div className="flex items-center gap-2">
                    <span
                      className="w-2.5 h-2.5 rounded-full"
                      style={{ backgroundColor: stall.accent_color }}
                    />
                    <h3 className="text-sm font-bold text-slate-900 font-display">
                      {stall.stall_name}
                    </h3>
                  </div>
                  <span className="text-[11px] font-semibold text-emerald-600 flex items-center gap-1">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                    OPEN
                  </span>
                </div>

                {/* 2-column cards grid exactly matching WhatsApp mockup */}
                <div className="grid grid-cols-2 gap-3.5">
                  {stallProducts.map((product) => {
                    const cartItem = cart.find(
                      (c) => c.product.product_id === product.product_id
                    );
                    const isSoldOut = product.stock_quantity <= 0;
                    const isLowStock = product.stock_quantity > 0 && product.stock_quantity <= 3;

                    return (
                      <div
                        key={product.product_id}
                        className={`rounded-3xl p-4 flex flex-col items-center text-center transition-all duration-200 border border-amber-100/80 ${
                          isSoldOut
                            ? 'bg-[#FAF6EE] opacity-75'
                            : 'bg-white shadow-[6px_6px_16px_rgba(215,190,150,0.2),-6px_-6px_16px_rgba(255,255,255,0.9)] hover:scale-[1.01]'
                        }`}
                      >
                        {/* Circular soft embossed badge for food graphic */}
                        <div className="w-16 h-16 rounded-full bg-[#FAF2E4] shadow-inner flex items-center justify-center mb-2.5 border border-amber-100">
                          {getFoodVisual(product)}
                        </div>

                        {/* Title */}
                        <h4 className="text-sm font-bold text-slate-900 leading-snug line-clamp-1">
                          {product.product_name}
                        </h4>

                        {/* Price in ₹ */}
                        <div className="text-sm font-extrabold text-slate-900 mt-0.5 font-mono">
                          ₹{product.price}
                        </div>

                        {/* Stock Tag matching exact screenshot text */}
                        <div className="mt-2 mb-3">
                          {isSoldOut ? (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-amber-100/60 text-[10px] font-bold text-amber-800 tracking-wider">
                              <span className="w-1.5 h-1.5 rounded-full bg-amber-600" />
                              SOLD OUT
                            </span>
                          ) : isLowStock ? (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-amber-100 text-[10px] font-bold text-amber-900 tracking-wider">
                              <span className="w-1.5 h-1.5 rounded-full bg-amber-600 animate-ping" />
                              ONLY {product.stock_quantity} LEFT
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-50 text-[10px] font-bold text-emerald-800 tracking-wider">
                              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                              IN STOCK
                            </span>
                          )}
                        </div>

                        {/* Vibrant Gradient Round Add Button */}
                        <div className="w-full flex justify-center">
                          {cartItem ? (
                            <div className="flex items-center gap-2 bg-[#FAF2E4] px-2.5 py-1 rounded-full border border-amber-200">
                              <button
                                onClick={() => updateCartQuantity(product.product_id, -1)}
                                className="w-6 h-6 rounded-full bg-white text-slate-700 flex items-center justify-center shadow-xs hover:bg-slate-100"
                              >
                                <Minus className="w-3 h-3" />
                              </button>
                              <span className="text-xs font-mono font-bold text-slate-900 min-w-[14px]">
                                {cartItem.quantity}
                              </span>
                              <button
                                onClick={() => updateCartQuantity(product.product_id, 1)}
                                className="w-6 h-6 rounded-full bg-[#E63E11] text-white flex items-center justify-center shadow-xs hover:bg-[#d4370d]"
                              >
                                <Plus className="w-3 h-3" />
                              </button>
                            </div>
                          ) : (
                            <button
                              disabled={isSoldOut}
                              onClick={() => {
                                const res = addToCart(product);
                                if (!res.success && res.reason) alert(res.reason);
                              }}
                              className={`w-9 h-9 rounded-full flex items-center justify-center shadow-md transition-all active:scale-95 ${
                                isSoldOut
                                  ? 'bg-slate-200 text-slate-400 cursor-not-allowed'
                                  : 'bg-gradient-to-br from-[#FF6E40] to-[#E63E11] text-white shadow-orange-500/30 hover:scale-105'
                              }`}
                              title={isSoldOut ? 'Sold out' : 'Add to cart'}
                            >
                              <Plus className="w-5 h-5 stroke-[2.5]" />
                            </button>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
      </div>

      {/* Floating Bottom Cart Bar (if items in cart) */}
      {cartItemCount > 0 && (
        <div className="fixed bottom-[calc(5rem+var(--sab))] inset-x-4 max-w-sm mx-auto z-30 animate-in slide-in-from-bottom duration-200">
          <div
            onClick={onOpenCart}
            className="p-3 bg-gradient-to-r from-[#FF6E40] to-[#E63E11] text-white rounded-2xl shadow-xl shadow-orange-950/20 flex items-center justify-between cursor-pointer hover:opacity-95 transition-all"
          >
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-xl bg-white/20 flex items-center justify-center font-bold text-xs font-mono">
                {cartItemCount}
              </div>
              <div>
                <span className="text-[10px] text-orange-100 block uppercase font-semibold">
                  {currentCanteen.canteen_name}
                </span>
                <span className="text-sm font-bold font-mono">₹{cartTotalAmount}</span>
              </div>
            </div>

            <div className="flex items-center gap-1 font-bold text-xs bg-white text-[#E63E11] px-3 py-1.5 rounded-xl shadow-sm">
              <span>View Cart</span>
              <span>→</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
