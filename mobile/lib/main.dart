import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/supabase/supabase_config.dart';
import 'injection_container.dart';
import 'app.dart';

/// REKBER — Application Entry Point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize dependency injection
  await initDependencies();

  runApp(const RekberApp());
}
