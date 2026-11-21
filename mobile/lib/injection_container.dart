import 'package:get_it/get_it.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

/// Service Locator — Dependency Injection Container
final sl = GetIt.instance;

/// Initialize all dependencies
Future<void> initDependencies() async {
  // ── Services ──
  sl.registerLazySingleton<ApiService>(() => ApiService());
  sl.registerLazySingleton<NotificationService>(() => NotificationService());

  // ── BLoCs ──
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(
      apiService: sl<ApiService>(),
      notificationService: sl<NotificationService>(),
    ),
  );
}
