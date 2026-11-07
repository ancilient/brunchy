import React from 'react';
import { useCanteen } from '../../context/CanteenContext';
import { UtensilsCrossed, Store, Clock, MapPin, ArrowRight, Flame } from 'lucide-react';

interface ChooseCanteenScreenProps {
  onCanteenChosen: () => void;
}

export const ChooseCanteenScreen: React.FC<ChooseCanteenScreenProps> = ({ onCanteenChosen }) => {
  const { canteens, stalls, setSelectedCanteenId, getLiveBusyLevel, cart, clearCart } = useCanteen();

  const handleSelect = (canteenId: number) => {
    if (cart.length > 0 && cart[0].product.canteen_id !== canteenId) {
      if (!confirm('Switching canteens will clear your current cart. Proceed?')) return;
      clearCart();
    }
    setSelectedCanteenId(canteenId);
    onCanteenChosen();
  };

  const mainCanteen = canteens.find((c) => c.canteen_id === 1) || canteens[0];
  const advanceCanteen = canteens.find((c) => c.canteen_id === 2) || canteens[1];

  return (
    <div className="min-h-screen bg-[#FAF2E4] flex flex-col justify-center items-center px-4 py-8">
      <div className="w-full max-w-sm">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#FF6E40] to-[#E63E11] text-white flex items-center justify-center mx-auto shadow-md shadow-orange-500/25 mb-3">
            <UtensilsCrossed className="w-7 h-7" />
          </div>
          <h2 className="text-2xl font-extrabold text-slate-900 font-display">
            Choose Your Canteen
          </h2>
          <p className="text-xs text-slate-600 mt-1">
            Where would you like to pick up your food?
          </p>
        </div>

        {/* Two Big Buttons per PDF */}
        <div className="space-y-4">
          {/* Big Button 1: Main Canteen */}
          <button
            onClick={() => handleSelect(mainCanteen.canteen_id)}
            className="w-full p-5 rounded-3xl bg-white hover:bg-orange-50/40 border-2 border-amber-200/80 shadow-lg shadow-amber-950/5 text-left transition-all active:scale-[0.98] group flex items-center justify-between"
          >
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-[10px] font-bold uppercase tracking-wider bg-orange-100 text-[#E63E11] px-2 py-0.5 rounded-md">
                  PRIMARY HUB
                </span>
                <span className="text-xs font-semibold text-emerald-600 flex items-center gap-1">
                  <span className="w-2 h-2 rounded-full bg-emerald-500" />
                  OPEN
                </span>
              </div>

              <h3 className="text-lg font-extrabold text-slate-900 font-display group-hover:text-[#E63E11] transition-colors">
                {mainCanteen.canteen_name}
              </h3>

              <div className="flex items-center gap-3 text-xs text-slate-500 mt-2">
                <span className="flex items-center gap-1">
                  <Clock className="w-3.5 h-3.5" />
                  {mainCanteen.opening_time} - {mainCanteen.closing_time}
                </span>
                <span>·</span>
                <span className="flex items-center gap-1">
                  <Store className="w-3.5 h-3.5" />
                  4 Stalls
                </span>
              </div>

              <div className="flex items-center gap-3 text-xs text-slate-500 mt-1">
                <span className="flex items-center gap-1">
                  <MapPin className="w-3.5 h-3.5 text-slate-400" />
                  250m away
                </span>
                <span>·</span>
                <span className="flex items-center gap-1 text-amber-700 font-medium">
                  <Flame className="w-3.5 h-3.5 text-amber-500" />
                  Busy: {getLiveBusyLevel(mainCanteen.canteen_id)}
                </span>
              </div>
            </div>

            <div className="w-10 h-10 rounded-2xl bg-orange-100 group-hover:bg-[#E63E11] text-[#E63E11] group-hover:text-white flex items-center justify-center transition-all ml-3 shrink-0">
              <ArrowRight className="w-5 h-5" />
            </div>
          </button>

          {/* Big Button 2: Advance Block Canteen */}
          <button
            onClick={() => handleSelect(advanceCanteen.canteen_id)}
            className="w-full p-5 rounded-3xl bg-white hover:bg-orange-50/40 border-2 border-amber-200/80 shadow-lg shadow-amber-950/5 text-left transition-all active:scale-[0.98] group flex items-center justify-between"
          >
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-[10px] font-bold uppercase tracking-wider bg-slate-100 text-slate-600 px-2 py-0.5 rounded-md">
                  BLOCK 3
                </span>
                <span className="text-xs font-semibold text-emerald-600 flex items-center gap-1">
                  <span className="w-2 h-2 rounded-full bg-emerald-500" />
                  OPEN
                </span>
              </div>

              <h3 className="text-lg font-extrabold text-slate-900 font-display group-hover:text-[#E63E11] transition-colors">
                {advanceCanteen.canteen_name}
              </h3>

              <div className="flex items-center gap-3 text-xs text-slate-500 mt-2">
                <span className="flex items-center gap-1">
                  <Clock className="w-3.5 h-3.5" />
                  {advanceCanteen.opening_time} - {advanceCanteen.closing_time}
                </span>
                <span>·</span>
                <span className="flex items-center gap-1">
                  <Store className="w-3.5 h-3.5" />
                  2 Stalls
                </span>
              </div>

              <div className="flex items-center gap-3 text-xs text-slate-500 mt-1">
                <span className="flex items-center gap-1">
                  <MapPin className="w-3.5 h-3.5 text-slate-400" />
                  550m away
                </span>
                <span>·</span>
                <span className="flex items-center gap-1 text-amber-700 font-medium">
                  <Flame className="w-3.5 h-3.5 text-amber-500" />
                  Busy: {getLiveBusyLevel(advanceCanteen.canteen_id)}
                </span>
              </div>
            </div>

            <div className="w-10 h-10 rounded-2xl bg-orange-100 group-hover:bg-[#E63E11] text-[#E63E11] group-hover:text-white flex items-center justify-center transition-all ml-3 shrink-0">
              <ArrowRight className="w-5 h-5" />
            </div>
          </button>
        </div>

        <p className="text-[11px] text-center text-slate-400 mt-6">
          You can switch canteen at any time from your Profile
        </p>
      </div>
    </div>
  );
};
