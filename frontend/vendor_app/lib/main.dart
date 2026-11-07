import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'injection_container.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initDependencies();
  runApp(const BrunchyVendorApp());
}
