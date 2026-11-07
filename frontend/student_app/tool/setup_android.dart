// Run once after `flutter create` made the android/ folder (the build scripts do this for you):
//   dart run tool/setup_android.dart
// Sets the app name "Brunchy", internet access (Google Fonts), and the cream launch background.
import 'dart:io';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stderr.writeln('android/ folder not found. Run: flutter create . --platforms=android --org com.ancilient --project-name brunchy');
    exit(1);
  }
  var m = manifest.readAsStringSync().replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="Brunchy"');
  if (!m.contains('android.permission.INTERNET')) {
    final tag = RegExp(r'<manifest[^>]*>').firstMatch(m)!.group(0)!;
    m = m.replaceFirst(tag, '$tag\n    <uses-permission android:name="android.permission.INTERNET" />');
  }
  manifest.writeAsStringSync(m);

  final colors = File('android/app/src/main/res/values/colors.xml');
  if (!colors.existsSync()) {
    colors.writeAsStringSync('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="brunchy_cream">#FAF2E4</color>\n</resources>\n');
  }
  for (final path in ['android/app/src/main/res/drawable/launch_background.xml', 'android/app/src/main/res/drawable-v21/launch_background.xml']) {
    final f = File(path);
    if (f.existsSync()) {
      f.writeAsStringSync(f.readAsStringSync()
          .replaceAll('@android:color/white', '@color/brunchy_cream')
          .replaceAll('?android:colorBackground', '@color/brunchy_cream'));
    }
  }
  final test = File('test/widget_test.dart'); // the template test refers to a counter app that does not exist here
  if (test.existsSync()) test.deleteSync();
  stdout.writeln('Android project set up: name Brunchy, internet permission, cream launch screen.');
}
