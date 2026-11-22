import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/services/notification_service.dart';
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

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Notifications
  await NotificationService().initialize();

  // Initialize dependency injection
  await initDependencies();

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
        options.beforeSend = (event, hint) {
          // Sensitive data scrubber: redact tokens, auth headers, passwords
          final headers = event.request?.headers;
          if (headers != null) {
            headers.remove('authorization');
            headers.remove('cookie');
            headers.remove('x-metrics-token');
          }
          return event;
        };
      },
      appRunner: () => runApp(const RekberApp()),
    );
  } else {
    runApp(const RekberApp());
  }
}
