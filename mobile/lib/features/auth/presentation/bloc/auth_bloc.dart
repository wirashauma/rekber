import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Auth BLoC — Manages authentication state using backend JWT and token refresh
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService _apiService;
  final NotificationService? _notificationService;
  StreamSubscription<void>? _sessionExpiredSubscription;
  StreamSubscription<String>? _fcmTokenSubscription;

  AuthBloc({
    required ApiService apiService,
    NotificationService? notificationService,
  })  : _apiService = apiService,
        _notificationService = notificationService,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckAuth);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthRoleSwitched>(_onRoleSwitch);
    on<AuthSessionExpiredEvent>(_onSessionExpired);

    // Listen for session expiration events emitted by ApiService on 401 refresh failure
    _sessionExpiredSubscription = _apiService.onSessionExpired.listen((_) {
      add(AuthSessionExpiredEvent());
    });

    // Listen for FCM token refreshes and update backend if authenticated
    final notifService = _notificationService;
    if (notifService != null) {
      _fcmTokenSubscription =
          notifService.onTokenRefresh.listen((newToken) async {
        if (state is AuthAuthenticated && newToken.isNotEmpty) {
          try {
            await _apiService
                .post('/auth/update-fcm', {'fcmToken': newToken});
          } catch (e) {
            if (kDebugMode) print('FCM token refresh sync error: $e');
          }
        }
      });
    }
  }

  Future<void> _onCheckAuth(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final token = await _apiService.getAccessToken();
    if (token == null || token.isEmpty) {
      emit(AuthUnauthenticated());
      return;
    }

    try {
      final response = await _apiService.get('/auth/me');
      if (response != null && response['data'] != null) {
        final user = _mapToEntity(response['data']);
        emit(AuthAuthenticated(user: user, activeRole: user.role));
      } else {
        await _apiService.clearTokens();
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      await _apiService.clearTokens();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final response = await _apiService.post('/auth/login', {
        'email': event.email,
        'password': event.password,
      });

      final data = response['data'];
      final accessToken = data['accessToken'] ?? data['token'];
      final refreshToken = data['refreshToken'];

      if (accessToken != null && refreshToken != null) {
        await _apiService.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } else if (accessToken != null) {
        await _apiService.saveToken(accessToken);
      }

      // Update FCM Token on backend (non-blocking)
      final notif = _notificationService;
      if (notif != null) {
        try {
          final fcmToken = await notif.getToken();
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await _apiService.post('/auth/update-fcm', {'fcmToken': fcmToken});
          }
        } catch (e) {
          if (kDebugMode) print('FCM update error: $e');
        }
      }

      final user = _mapToEntity(data['user']);
      emit(AuthAuthenticated(user: user, activeRole: user.role));
    } on ApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (_) {
      emit(const AuthError(message: 'Terjadi kesalahan. Coba lagi nanti.'));
    }
  }

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final payload = {
        'name': event.fullName,
        'email': event.email,
        'password': event.password,
      };

      await _apiService.post('/auth/register', payload);

      emit(const AuthRegistrationSuccess(
        message: 'Registrasi berhasil! Silakan login.',
      ));
    } on ApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (_) {
      emit(const AuthError(message: 'Registrasi gagal. Coba lagi nanti.'));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final refreshToken = await _apiService.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiService.post('/auth/logout', {'refreshToken': refreshToken});
      }
    } catch (e) {
      if (kDebugMode) print('Logout error: $e');
    } finally {
      await _apiService.clearTokens();
      emit(AuthUnauthenticated());
    }
  }

  void _onRoleSwitch(
    AuthRoleSwitched event,
    Emitter<AuthState> emit,
  ) {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      emit(AuthAuthenticated(
        user: currentState.user,
        activeRole: event.newRole,
      ));
    }
  }

  void _onSessionExpired(
    AuthSessionExpiredEvent event,
    Emitter<AuthState> emit,
  ) {
    emit(AuthSessionExpired());
  }

  UserEntity _mapToEntity(Map<String, dynamic> data) {
    return UserModel.fromJson(data);
  }

  @override
  Future<void> close() {
    _sessionExpiredSubscription?.cancel();
    _fcmTokenSubscription?.cancel();
    return super.close();
  }
}
