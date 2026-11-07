// One command to build the Android APK:  npm run apk
// Needs: Node 22+, JDK 21, and the Android SDK (install Android Studio once; it sets everything up).
import { existsSync, copyFileSync, readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import path from 'node:path';

const win = process.platform === 'win32';
const run = (cmd, cwd) => { console.log(`\n> ${cmd}`); execSync(cmd, { stdio: 'inherit', cwd }); };
const fail = (msg) => { console.error(`\nERROR: ${msg}\n`); process.exit(1); };

// --- checks with plain-language fixes ---
const nodeMajor = Number(process.versions.node.split('.')[0]);
if (nodeMajor < 22) fail(`Node ${process.versions.node} is too old. Capacitor 8 needs Node 22 or newer: install it from https://nodejs.org`);
if (!existsSync('node_modules/@capacitor/cli')) fail('Packages are not installed. Run `npm install` first.');
let javaOut = '';
try { javaOut = execSync('java -version 2>&1', { encoding: 'utf8' }); }
catch { fail('Java (JDK 21) not found. Install Android Studio, or a JDK 21, and set JAVA_HOME.'); }
const javaMajor = Number((javaOut.match(/version "(\d+)/) || [])[1]);
if (javaMajor && javaMajor < 21) fail(`Java ${javaMajor} found, but the Android build needs JDK 21. Point JAVA_HOME at a JDK 21 (Android Studio ships one: File > Settings > Build Tools > Gradle > Gradle JDK shows its path).`);
const sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT ||
  (win ? path.join(process.env.LOCALAPPDATA || '', 'Android', 'Sdk') : path.join(process.env.HOME || '', process.platform === 'darwin' ? 'Library/Android/sdk' : 'Android/Sdk'));
if (!existsSync(sdk)) fail(`Android SDK not found (looked in ${sdk}). Install Android Studio and open it once, or set ANDROID_HOME.`);
process.env.ANDROID_HOME = sdk;

// An android/ folder made by an older Capacitor version does not build with Capacitor 8: start it fresh.
if (existsSync('android/capacitor.settings.gradle') && existsSync('android/variables.gradle')) {
  const vars = readFileSync('android/variables.gradle', 'utf8');
  if (!/compileSdkVersion\s*=\s*3[6-9]/.test(vars)) fail('The android/ folder was made by an older Capacitor version. Delete the android folder and run `npm run apk` again.');
}

// --- build the web app, create/refresh the Android project, build the APK ---
run('npm run build');
if (!existsSync('android')) {
  run('npx cap add android');
  try { run('npx --yes @capacitor/assets generate --android --iconBackgroundColor "#E63E11" --iconBackgroundColorDark "#E63E11" --splashBackgroundColor "#FAF2E4" --splashBackgroundColorDark "#FAF2E4"'); }
  catch { console.warn('Icon generation failed; the APK will use the default Capacitor icon.'); }
}
run('npx cap sync android');
run(win ? 'gradlew.bat assembleDebug' : './gradlew assembleDebug', 'android');

const apk = path.join('android', 'app', 'build', 'outputs', 'apk', 'debug', 'app-debug.apk');
if (!existsSync(apk)) fail('Gradle finished but no APK was found.');
copyFileSync(apk, 'Brunchy.apk');
console.log(`\nDone: ${path.resolve('Brunchy.apk')}\nCopy it to your phone and open it to install (allow "install unknown apps" when asked).`);
