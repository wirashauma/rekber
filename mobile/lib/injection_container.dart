import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/services/api_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

/// Service Locator — Dependency Injection Container
final sl = GetIt.instance;

/// Initialize all dependencies
Future<void> initDependencies() async {
  // ── Firebase ──
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);

  // ── Services ──
  sl.registerLazySingleton<ApiService>(() => ApiService());

  // ── BLoCs ──
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      firebaseAuth: sl<FirebaseAuth>(),
      apiService: sl<ApiService>(),
    ),
  );
}
