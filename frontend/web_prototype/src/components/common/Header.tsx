import React from 'react';
import { useCanteen } from '../../context/CanteenContext';
import {
  UtensilsCrossed,
  RotateCcw,
  Clock
} from 'lucide-react';

interface HeaderProps {
  onReplaySplash?: () => void;
}

export const Header: React.FC<HeaderProps> = ({ onReplaySplash }) => {
  const {
    demoClockMultiplier,
    setDemoClockMultiplier,
  } = useCanteen();

  return (
    <header className="sticky top-0 z-40 bg-[#FAF2E4] border-b border-amber-200/60 shadow-xs pt-[var(--sat)]">
      <div className="max-w-md mx-auto px-4 py-3">
        <div className="flex items-center justify-between gap-3">
          {/* Brand & Subtitle (Student focused, campus v3.1 removed) */}
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-2xl bg-gradient-to-br from-[#FF6E40] to-[#E63E11] text-white flex items-center justify-center shadow-md shadow-orange-500/25 shrink-0">
              <UtensilsCrossed className="w-5 h-5 stroke-[2.5]" />
            </div>
            <div>
              <span className="text-xl font-extrabold text-slate-900 font-display tracking-tight leading-none block">
                Brunchy
              </span>
              <p className="text-[10px] text-slate-500 font-medium mt-0.5">
                Campus Canteen Ordering
              </p>
            </div>
          </div>

          {/* Right Controls: Demo Clock Pills & Replay Splash */}
          <div className="flex items-center gap-2">
            {/* DEMO CLOCK Speed Multipliers: 1x, 10x, 30x matching screenshot */}
            <div className="flex items-center gap-1 bg-white px-2.5 py-1 rounded-full border border-amber-200/80 shadow-xs">
              <span className="text-[9px] font-bold uppercase tracking-wider text-slate-400 mr-0.5 flex items-center gap-1">
                <Clock className="w-3 h-3 text-[#E63E11]" />
                <span className="hidden sm:inline">CLOCK</span>
              </span>
              {[1, 10, 30].map((mult) => (
                <button
                  key={mult}
                  onClick={() => setDemoClockMultiplier(mult as 1 | 10 | 30)}
                  className={`w-6 h-6 rounded-full text-[11px] font-bold transition-all flex items-center justify-center font-mono ${
                    demoClockMultiplier === mult
                      ? 'bg-gradient-to-r from-[#FF6E40] to-[#E63E11] text-white shadow-xs scale-105'
                      : 'text-slate-600 hover:bg-slate-100'
                  }`}
                  title={`${mult}x simulation speed`}
                >
                  {mult}x
                </button>
              ))}
            </div>

            {/* Replay Logo Splash button */}
            {onReplaySplash && (
              <button
                onClick={onReplaySplash}
                className="p-1.5 text-slate-500 hover:text-[#E63E11] transition-colors rounded-full bg-white border border-amber-200/80"
                title="Replay 1-sec Logo Animation"
              >
                <RotateCcw className="w-3.5 h-3.5" />
              </button>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};
