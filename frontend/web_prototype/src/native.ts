// Small bridge to the Android app shell (Capacitor). Everything here is a no-op in a normal browser.
import { useEffect, useRef } from 'react';
import { Capacitor } from '@capacitor/core';

/** Higher runs first: open popups, then screens, then the app shell. */
export const BACK_PRIORITY = { MODAL: 10, SCREEN: 5, SHELL: 0 } as const;

type Entry = { handler: { current: () => boolean }; priority: number; seq: number };
const entries: Entry[] = [];
let seq = 0;
let listening = false;

/** Runs the registered back handlers; returns true if one of them handled the press. */
export function handleBackPress(): boolean {
  const ordered = [...entries].sort((a, b) => b.priority - a.priority || b.seq - a.seq);
  return ordered.some((e) => e.handler.current());
}

function ensureListener() {
  if (listening || !Capacitor.isNativePlatform()) return;
  listening = true;
  import('@capacitor/app')
    .then(({ App }) =>
      App.addListener('backButton', () => {
        if (!handleBackPress()) App.minimizeApp();      // nothing left to close: leave the app like other Android apps
      }),
    )
    .catch(() => { listening = false; });
}

/** Calls handler on the Android back button. Return true if you handled it; if nobody does, the app is minimised. */
export function useAndroidBack(handler: () => boolean, priority: number = BACK_PRIORITY.SCREEN) {
  const h = useRef(handler);
  h.current = handler;
  useEffect(() => {
    const entry: Entry = { handler: h, priority, seq: seq++ };
    entries.push(entry);
    ensureListener();
    return () => { const i = entries.indexOf(entry); if (i >= 0) entries.splice(i, 1); };
  }, [priority]);
}

// Lets automated browser tests press "back" (window.__androidBack()). Harmless in the app.
if (typeof window !== 'undefined') (window as unknown as { __androidBack: () => boolean }).__androidBack = handleBackPress;
