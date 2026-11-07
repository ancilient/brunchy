import React, { useEffect, useRef, useState } from 'react';
import { UtensilsCrossed, Sparkles } from 'lucide-react';

interface SplashLogoProps {
  onFinish: () => void;
}

export const SplashLogo: React.FC<SplashLogoProps> = ({ onFinish }) => {
  const [fading, setFading] = useState<boolean>(false);
  const finish = useRef(onFinish);
  finish.current = onFinish;

  useEffect(() => {
    // 1-second animation per PDF. Runs once: re-renders of the parent must not restart it.
    const fadeTimer = setTimeout(() => setFading(true), 1100);
    const closeTimer = setTimeout(() => finish.current(), 1400);
    return () => { clearTimeout(fadeTimer); clearTimeout(closeTimer); };
  }, []);

  return (
    <div
      className={`fixed inset-0 z-50 flex flex-col items-center justify-center bg-[#FAF2E4] transition-opacity duration-300 ${
        fading ? 'opacity-0 pointer-events-none' : 'opacity-100'
      }`}
    >
      <div className="flex flex-col items-center animate-in zoom-in-95 duration-500">
        {/* Soft 3D embossed logo disc */}
        <div className="w-24 h-24 rounded-3xl bg-gradient-to-br from-[#FF6E40] to-[#E63E11] text-white flex items-center justify-center shadow-2xl shadow-orange-500/40 relative">
          <UtensilsCrossed className="w-12 h-12 stroke-[2.5]" />
          <div className="absolute -top-1.5 -right-1.5 w-6 h-6 rounded-full bg-amber-300 flex items-center justify-center text-amber-900 shadow-md">
            <Sparkles className="w-3.5 h-3.5" />
          </div>
        </div>

        <h1 className="text-4xl font-extrabold text-slate-900 font-display tracking-tight mt-5">
          Brunchy
        </h1>
        <p className="text-xs font-semibold uppercase tracking-widest text-[#E63E11] mt-1">
          Campus Food Ordering
        </p>

        <div className="w-10 h-1 bg-gradient-to-r from-orange-400 to-amber-400 rounded-full mt-6 animate-pulse" />
      </div>
    </div>
  );
};
