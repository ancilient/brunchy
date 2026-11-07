# Changes in this version

## Build fixes (the APK could not be built before)
- `package.json` was missing the Capacitor packages (`@capacitor/core`, `@capacitor/app`, `@capacitor/android`, `@capacitor/cli`) and the `apk` script. Added; unused packages (Gemini, Express, dotenv, motion) removed.
- Updated for Capacitor 8 (the current version): the old `adjustMarginsForEdgeToEdge` setting no longer exists, so on Android 15+ the header and bottom bar would have gone under the status bar and gesture bar. Now uses the SystemBars setting plus safe-area padding.
- `npm run apk` now checks Node 22+, JDK 21 and an old `android/` folder, with plain-language fixes.
- Added a GitHub Actions workflow that builds the APK in the cloud.
- The client's blueprint PDFs and WhatsApp image were in `public/`, so they would have been packaged inside the APK for anyone to extract. Moved to `docs/client-reference/`.

## App fixes
- Orders, cart and stock are now saved on the phone. Before, Android closing the app (common while a UPI app is open) lost every order and its pickup code.
- A payment that was in progress when the app closed is released on the next start, so its items are not held forever.
- Logging out now stays logged out after a restart (before, the demo student was signed back in).
- Logging in with the same phone number gives the same account, so past orders come back.
- Reorder (Profile) added only the last item of an order; it now adds every item and says when one is sold out or unavailable.
- A cancelled or rejected order showed "Counter Pickup Code: 345"; it now shows that the order was cancelled and refunded.
- The hand-over button found the order by its code text, which could match a different bill's number; it now completes exactly that bill.
- After the "Limited stock" prompt, the payment sheet did not open; it now does, with the corrected amount.
- When the 5-minute payment hold ran out, the payment sheet just vanished; it now closes with a message.
- Android back button: closes the open popup first, then returns to Home, then leaves the app. Before, it closed the app from any screen.
- Home showed a fixed time ("12:52 pm"); it now shows the phone's time.
- The splash animation timer no longer restarts if the screen re-renders.
- Totals are rounded to paise to avoid values like ₹84.00000001.

## Flutter version (new)
- `flutter_app/` is the same app rewritten in Flutter: same screens, flow, wording, colours, fonts, icons, menu data and demo behaviour, including all the fixes above.
- Build it with `flutter_app/build-apk.bat` (Windows) or `build-apk.sh`, or the "Build Flutter APK" GitHub Action.
