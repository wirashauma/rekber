import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

/// Service Locator — Dependency Injection Container
final sl = GetIt.instance;

/// Initialize all dependencies
Future<void> initDependencies() async {
  // ── External ──
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // ── BLoCs ──
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(supabaseClient: sl<SupabaseClient>()),
  );

  // TODO: Register additional BLoCs as features are built
  // sl.registerFactory<TransactionBloc>(() => TransactionBloc(...));
  // sl.registerFactory<ChatBloc>(() => ChatBloc(...));
  // sl.registerFactory<WalletBloc>(() => WalletBloc(...));
  // sl.registerFactory<ProductBloc>(() => ProductBloc(...));
}
