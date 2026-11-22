import 'package:get_it/get_it.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/socket_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/transaction/domain/repositories/transaction_repository.dart';
import 'features/transaction/data/repositories/transaction_repository_impl.dart';
import 'features/transaction/presentation/cubit/transaction_cubit.dart';
import 'features/wallet/domain/repositories/wallet_repository.dart';
import 'features/wallet/data/repositories/wallet_repository_impl.dart';
import 'features/wallet/presentation/cubit/wallet_cubit.dart';
import 'features/dispute/domain/repositories/dispute_repository.dart';
import 'features/dispute/data/repositories/dispute_repository_impl.dart';
import 'features/dispute/presentation/cubit/dispute_cubit.dart';
import 'features/chat/domain/repositories/chat_repository.dart';
import 'features/chat/data/repositories/chat_repository_impl.dart';
import 'features/chat/presentation/bloc/chat_bloc.dart';
import 'features/notification/domain/repositories/notification_repository.dart';
import 'features/notification/data/repositories/notification_repository_impl.dart';
import 'features/notification/presentation/cubit/notification_cubit.dart';
import 'features/settings/domain/repositories/kyc_repository.dart';
import 'features/settings/data/repositories/kyc_repository_impl.dart';
import 'features/settings/presentation/cubit/kyc_cubit.dart';
import 'features/admin/domain/repositories/admin_repository.dart';
import 'features/admin/data/repositories/admin_repository_impl.dart';
import 'features/admin/presentation/cubit/admin_cubit.dart';

/// Service Locator — Dependency Injection Container
final sl = GetIt.instance;

/// Initialize all dependencies
Future<void> initDependencies() async {
  // ── Services ──
  sl.registerLazySingleton<ApiService>(() => ApiService());
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerLazySingleton<SocketService>(() => SocketService(apiService: sl<ApiService>()));

  // ── Repositories ──
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(apiService: sl<ApiService>()),
  );
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(apiService: sl<ApiService>()),
  );
  sl.registerLazySingleton<DisputeRepository>(
    () => DisputeRepositoryImpl(apiService: sl<ApiService>()),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(apiService: sl<ApiService>()),
  );
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(apiService: sl<ApiService>()),
  );
  sl.registerLazySingleton<KycRepository>(
    () => KycRepositoryImpl(apiService: sl<ApiService>()),
  );
  sl.registerLazySingleton<AdminRepository>(
    () => AdminRepositoryImpl(apiService: sl<ApiService>()),
  );

  // ── BLoCs & Cubits ──
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(
      apiService: sl<ApiService>(),
      notificationService: sl<NotificationService>(),
    ),
  );
  sl.registerFactory<TransactionCubit>(
    () => TransactionCubit(repository: sl<TransactionRepository>()),
  );
  sl.registerFactory<WalletCubit>(
    () => WalletCubit(repository: sl<WalletRepository>()),
  );
  sl.registerFactory<DisputeCubit>(
    () => DisputeCubit(repository: sl<DisputeRepository>()),
  );
  sl.registerFactory<ChatBloc>(
    () => ChatBloc(
      repository: sl<ChatRepository>(),
      socketService: sl<SocketService>(),
    ),
  );
  sl.registerFactory<NotificationCubit>(
    () => NotificationCubit(repository: sl<NotificationRepository>()),
  );
  sl.registerFactory<KycCubit>(
    () => KycCubit(kycRepository: sl<KycRepository>()),
  );
  sl.registerFactory<AdminCubit>(
    () => AdminCubit(adminRepository: sl<AdminRepository>()),
  );
}
