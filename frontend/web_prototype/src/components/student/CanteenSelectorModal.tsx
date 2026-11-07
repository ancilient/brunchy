import React from 'react';
import { useCanteen } from '../../context/CanteenContext';
import { useAndroidBack, BACK_PRIORITY } from '../../native';
import { X, MapPin, Clock, Store, Flame, Compass } from 'lucide-react';

interface CanteenSelectorModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const CanteenSelectorModal: React.FC<CanteenSelectorModalProps> = ({ isOpen, onClose }) => {
  const {
    canteens,
    stalls,
    selectedCanteenId,
    setSelectedCanteenId,
    cart,
    clearCart,
    getLiveBusyLevel,
  } = useCanteen();

  useAndroidBack(() => {
    if (!isOpen) return false;
    onClose();
    return true;
  }, BACK_PRIORITY.MODAL);

  if (!isOpen) return null;

  const handleSelectCanteen = (canteenId: number, isClosed: boolean) => {
    if (isClosed) return;

    if (cart.length > 0 && selectedCanteenId !== canteenId) {
      const confirmSwitch = window.confirm(
        'One cart equals one canteen. Switching canteens will clear your current cart. Switch now?'
      );
      if (!confirmSwitch) return;
      clearCart();
    }

    setSelectedCanteenId(canteenId);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-150">
      <div className="relative w-full max-w-md bg-white rounded-3xl shadow-2xl border border-slate-100 overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-5 border-b border-slate-100">
          <div>
            <h3 className="text-xl font-bold text-slate-900 font-display">Choose your canteen</h3>
            <p className="text-xs text-slate-500 mt-0.5">Switch any time · One cart = one canteen</p>
          </div>
          <button
            onClick={onClose}
            className="w-9 h-9 flex items-center justify-center rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Location Hint & Canteen Cards */}
        <div className="p-6 space-y-4 max-h-[75vh] overflow-y-auto">
          <div className="flex items-center justify-between px-4 py-2.5 bg-slate-50 border border-slate-200/70 rounded-2xl">
            <div className="flex items-center gap-2 text-xs text-slate-600">
              <Compass className="w-4 h-4 text-indigo-600 animate-spin" />
              <span>Main campus GPS active</span>
            </div>
            <span className="text-xs font-semibold text-indigo-600">Sorted nearest</span>
          </div>

          <div className="space-y-3">
            {canteens.map((canteen) => {
              const canteenStalls = stalls.filter((s) => s.canteen_id === canteen.canteen_id);
              const isSelected = selectedCanteenId === canteen.canteen_id;
              const isClosed = canteen.status === 'closed';
              const busyLevel = getLiveBusyLevel(canteen.canteen_id);

              return (
                <div
                  key={canteen.canteen_id}
                  onClick={() => handleSelectCanteen(canteen.canteen_id, isClosed)}
                  className={`p-4 rounded-2xl border-2 transition-all cursor-pointer relative ${
                    isClosed
                      ? 'bg-slate-50/80 border-slate-200 opacity-60 cursor-not-allowed'
                      : isSelected
                      ? 'bg-indigo-50/50 border-[#3A3D9E] shadow-sm'
                      : 'bg-white border-slate-200 hover:border-slate-300 hover:shadow-sm'
                  }`}
                >
                  <div className="flex items-start justify-between">
                    <div>
                      <div className="flex items-center gap-2">
                        <h4 className="text-base font-bold text-slate-900 font-display">
                          {canteen.canteen_name}
                        </h4>
                        {isSelected && (
                          <span className="text-[10px] font-semibold bg-indigo-100 text-[#3A3D9E] px-2 py-0.5 rounded-md">
                            CURRENT
                          </span>
                        )}
                        {canteen.canteen_id === 1 && !isSelected && (
                          <span className="text-[10px] font-semibold bg-slate-100 text-slate-600 px-2 py-0.5 rounded-md">
                            LAST USED
                          </span>
                        )}
                      </div>

                      <div className="flex items-center gap-3 text-xs text-slate-500 mt-2">
                        <span className="flex items-center gap-1">
                          <Clock className="w-3.5 h-3.5" />
                          {canteen.opening_time} - {canteen.closing_time}
                        </span>
                        <span>·</span>
                        <span className="flex items-center gap-1">
                          <Store className="w-3.5 h-3.5" />
                          {canteenStalls.length} stalls
                        </span>
                      </div>

                      <div className="flex items-center gap-3 text-xs mt-2.5">
                        <span className="flex items-center gap-1 font-medium text-slate-600">
                          <MapPin className="w-3.5 h-3.5 text-slate-400" />
                          {canteen.distance_meters} m away
                        </span>
                        <span>·</span>
                        <span
                          className={`flex items-center gap-1 font-medium ${
                            busyLevel === 'High'
                              ? 'text-rose-600'
                              : busyLevel === 'Medium'
                              ? 'text-amber-600'
                              : 'text-emerald-600'
                          }`}
                        >
                          <Flame className="w-3.5 h-3.5" />
                          Busy: {busyLevel}
                        </span>
                      </div>
                    </div>

                    <div>
                      {isClosed ? (
                        <div className="text-right">
                          <span className="text-xs font-bold text-slate-500 bg-slate-200 px-2.5 py-1 rounded-lg">
                            CLOSED
                          </span>
                          <p className="text-[11px] text-slate-500 mt-1">Opens at 6:00 PM</p>
                        </div>
                      ) : (
                        <span className="text-xs font-bold text-emerald-700 bg-emerald-100 px-2.5 py-1 rounded-lg">
                          OPEN
                        </span>
                      )}
                    </div>
                  </div>

                  {isClosed && (
                    <div className="mt-3 pt-2.5 border-t border-slate-200 text-xs text-slate-500">
                      Ordering not available now · Opens at 6:00 PM for night snacks
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};
