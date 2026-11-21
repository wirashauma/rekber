import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'config/routes/app_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'injection_container.dart';

/// REKBER App — Root widget
class RekberApp extends StatefulWidget {
  const RekberApp({super.key});

  @override
  State<RekberApp> createState() => _RekberAppState();
}

class _RekberAppState extends State<RekberApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>()..add(AuthCheckRequested());
    _router = AppRouter.createRouter(_authBloc);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(
          value: _authBloc,
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
