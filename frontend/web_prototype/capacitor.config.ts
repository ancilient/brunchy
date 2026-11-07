import type { CapacitorConfig } from '@capacitor/cli';

// Android app wrapper for the Brunchy web app. `npm run apk` (or the GitHub Action) builds the APK from this.
const config: CapacitorConfig = {
  appId: 'com.ancilient.brunchy',
  appName: 'Brunchy',
  webDir: 'dist',
  backgroundColor: '#FAF2E4',
  plugins: {
    // Capacitor 8: Android 15+ draws the app edge-to-edge. 'css' mode gives the web app the real status-bar and
    // gesture-bar sizes as --safe-area-inset-* CSS variables (used in src/index.css), including on older WebViews.
    // LIGHT = dark status-bar icons, readable on the app's light cream background.
    SystemBars: {
      insetsHandling: 'css',
      style: 'LIGHT',
    },
  },
};

export default config;
