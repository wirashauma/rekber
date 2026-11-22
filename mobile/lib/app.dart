import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'config/routes/app_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/transaction/presentation/cubit/transaction_cubit.dart';
import 'features/wallet/presentation/cubit/wallet_cubit.dart';
import 'features/dispute/presentation/cubit/dispute_cubit.dart';
import 'features/chat/presentation/bloc/chat_bloc.dart';
import 'features/notification/presentation/cubit/notification_cubit.dart';
import 'features/admin/presentation/cubit/admin_cubit.dart';
import 'injection_container.dart';

/// REKBER App — Root widget
class RekberApp extends StatefulWidget {
  const RekberApp({super.key});

  @override
  State<RekberApp> createState() => _RekberAppState();
}

class _RekberAppState extends State<RekberApp> {
  late final AuthBloc _authBloc;
  late final TransactionCubit _transactionCubit;
  late final WalletCubit _walletCubit;
  late final DisputeCubit _disputeCubit;
  late final ChatBloc _chatBloc;
  late final NotificationCubit _notificationCubit;
  late final AdminCubit _adminCubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>()..add(AuthCheckRequested());
    _transactionCubit = sl<TransactionCubit>();
    _walletCubit = sl<WalletCubit>();
    _disputeCubit = sl<DisputeCubit>();
    _chatBloc = sl<ChatBloc>();
    _notificationCubit = sl<NotificationCubit>();
    _adminCubit = sl<AdminCubit>();
    _router = AppRouter.createRouter(_authBloc);

    // Initialize Push Notification Service with Router navigation
    sl<NotificationService>().initialize(
      onNavigate: (route) {
        _router.push(route);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(
          value: _authBloc,
        ),
        BlocProvider<TransactionCubit>.value(
          value: _transactionCubit,
        ),
        BlocProvider<WalletCubit>.value(
          value: _walletCubit,
        ),
        BlocProvider<DisputeCubit>.value(
          value: _disputeCubit,
        ),
        BlocProvider<ChatBloc>.value(
          value: _chatBloc,
        ),
        BlocProvider<NotificationCubit>.value(
          value: _notificationCubit,
        ),
        BlocProvider<AdminCubit>.value(
          value: _adminCubit,
        ),
      ],
      child: MaterialApp.router(
        title: 'REKBER - Escrow Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}
