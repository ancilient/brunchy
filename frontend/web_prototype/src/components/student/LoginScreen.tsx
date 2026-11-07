import React, { useState } from 'react';
import { useCanteen } from '../../context/CanteenContext';
import { useAndroidBack, BACK_PRIORITY } from '../../native';
import { UtensilsCrossed, ArrowRight, ShieldCheck, Phone, User, Award } from 'lucide-react';

interface LoginScreenProps {
  onLoginSuccess: () => void;
}

export const LoginScreen: React.FC<LoginScreenProps> = ({ onLoginSuccess }) => {
  const { completeStudentLogin } = useCanteen();
  const [name, setName] = useState<string>('Priya R.');
  const [phone, setPhone] = useState<string>('9845012345');
  const [regNo, setRegNo] = useState<string>('ENG2024-8842');
  const [step, setStep] = useState<'details' | 'otp'>('details');
  const [otp, setOtp] = useState<string>('1234');

  useAndroidBack(() => {
    if (step !== 'otp') return false;
    setStep('details');
    return true;
  }, BACK_PRIORITY.SCREEN);

  const handleSendOtp = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !phone.trim()) return;
    setStep('otp');
  };

  const handleVerifyOtp = (e: React.FormEvent) => {
    e.preventDefault();
    completeStudentLogin(name.trim(), phone.trim(), regNo.trim());
    onLoginSuccess();
  };

  return (
    <div className="min-h-screen bg-[#FAF2E4] flex flex-col justify-center items-center px-4 py-8">
      <div className="w-full max-w-sm bg-white rounded-3xl p-6 sm:p-8 shadow-xl shadow-amber-950/5 border border-amber-100">
        {/* Logo and Greeting */}
        <div className="text-center mb-6">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[#FF6E40] to-[#E63E11] text-white flex items-center justify-center mx-auto shadow-md shadow-orange-500/30 mb-3">
            <UtensilsCrossed className="w-8 h-8" />
          </div>
          <h2 className="text-2xl font-extrabold text-slate-900 font-display">
            Welcome to Brunchy
          </h2>
          <p className="text-xs text-slate-500 mt-1">
            Skip the canteen queue · Order in 30 seconds
          </p>
        </div>

        {step === 'details' ? (
          <form onSubmit={handleSendOtp} className="space-y-4 text-xs">
            <div>
              <label className="font-semibold text-slate-700 block mb-1">
                Your Full Name
              </label>
              <div className="relative">
                <User className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. Priya Sharma"
                  className="w-full pl-9 pr-3 py-3 rounded-2xl bg-slate-50 border border-slate-200 text-slate-800 text-xs font-medium focus:ring-2 focus:ring-[#FF6E40] focus:outline-none"
                />
              </div>
            </div>

            <div>
              <label className="font-semibold text-slate-700 block mb-1">
                Mobile Number (for Order SMS)
              </label>
              <div className="relative flex">
                <span className="inline-flex items-center px-3 rounded-l-2xl border border-r-0 border-slate-200 bg-slate-100 text-slate-500 font-medium">
                  +91
                </span>
                <input
                  type="tel"
                  required
                  maxLength={10}
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="98765 43210"
                  className="w-full px-3 py-3 rounded-r-2xl bg-slate-50 border border-slate-200 text-slate-800 text-xs font-mono font-medium focus:ring-2 focus:ring-[#FF6E40] focus:outline-none"
                />
              </div>
            </div>

            <div>
              <label className="font-semibold text-slate-700 block mb-1">
                Campus Reg Number <span className="text-slate-400 font-normal">(Optional)</span>
              </label>
              <div className="relative">
                <Award className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  type="text"
                  value={regNo}
                  onChange={(e) => setRegNo(e.target.value)}
                  placeholder="e.g. ENG2024-8842"
                  className="w-full pl-9 pr-3 py-3 rounded-2xl bg-slate-50 border border-slate-200 text-slate-800 text-xs font-mono font-medium focus:ring-2 focus:ring-[#FF6E40] focus:outline-none"
                />
              </div>
            </div>

            <button
              type="submit"
              className="w-full mt-2 py-3.5 bg-gradient-to-r from-[#FF6E40] to-[#E63E11] hover:from-[#f56133] hover:to-[#d63408] text-white rounded-2xl font-bold text-xs flex items-center justify-center gap-2 shadow-lg shadow-orange-500/25 active:scale-[0.98] transition-all"
            >
              <span>Continue with SMS OTP</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </form>
        ) : (
          <form onSubmit={handleVerifyOtp} className="space-y-4 text-xs">
            <div className="p-3 bg-amber-50 rounded-2xl border border-amber-200/80 text-center">
              <span className="text-slate-600 block text-[11px]">
                Enter 4-digit code sent to +91 {phone}
              </span>
              <span className="text-[10px] text-amber-700 font-semibold block mt-0.5">
                (Demo auto-fill: 1234)
              </span>
            </div>

            <div className="flex justify-center">
              <input
                type="text"
                maxLength={4}
                value={otp}
                onChange={(e) => setOtp(e.target.value)}
                className="w-36 text-center tracking-[1em] py-3 text-lg font-mono font-bold bg-slate-50 border border-slate-200 rounded-2xl focus:ring-2 focus:ring-[#FF6E40] focus:outline-none"
              />
            </div>

            <button
              type="submit"
              className="w-full py-3.5 bg-gradient-to-r from-[#FF6E40] to-[#E63E11] hover:from-[#f56133] hover:to-[#d63408] text-white rounded-2xl font-bold text-xs flex items-center justify-center gap-2 shadow-lg shadow-orange-500/25 active:scale-[0.98] transition-all"
            >
              <ShieldCheck className="w-4 h-4" />
              <span>Verify & Remember Me</span>
            </button>

            <button
              type="button"
              onClick={() => setStep('details')}
              className="w-full text-center text-slate-500 hover:text-slate-800 text-[11px]"
            >
              Change Phone Number
            </button>
          </form>
        )}

        <div className="mt-6 pt-4 border-t border-slate-100 text-center text-[10px] text-slate-400">
          By signing up, you agree to Brunchy Canteen Terms & Privacy Notice
        </div>
      </div>
    </div>
  );
};
