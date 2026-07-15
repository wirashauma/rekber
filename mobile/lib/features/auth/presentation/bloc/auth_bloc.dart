import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Auth BLoC — Manages authentication state using Firebase Auth & Custom Backend
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _firebaseAuth;
  final ApiService _apiService;

  AuthBloc({
    required FirebaseAuth firebaseAuth,
    required ApiService apiService,
  })  : _firebaseAuth = firebaseAuth,
        _apiService = apiService,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckAuth);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthRoleSwitched>(_onRoleSwitch);
  }

  Future<void> _onCheckAuth(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final currentUser = _firebaseAuth.currentUser;
    final localToken = await _apiService.getToken();

    if (currentUser == null && localToken == null) {
      emit(AuthUnauthenticated());
      return;
    }

    try {
      // Sync/Fetch user data from custom backend using UID
      final response = await _apiService.get('/auth/me');
      final user = _mapToEntity(response['data']);
      emit(AuthAuthenticated(user: user, activeRole: user.role));
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // 1. Sign in with Firebase (Optional for test accounts)
      String? firebaseUid;
      try {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: event.email,
          password: event.password,
        );
        firebaseUid = credential.user?.uid;
      } catch (e) {
        if (kDebugMode) print('Firebase Auth Error: $e');
        // If it's a test account from seeds, we continue to backend login
        if (!event.email.endsWith('@rekber.com')) {
          rethrow;
        }
      }

      // 2. Authenticate with Custom Backend to get JWT
      final response = await _apiService.post('/auth/login', {
        'email': event.email,
        'password': event.password,
        'firebaseUid': firebaseUid,
      });

      final token = response['data']['token'];
      await _apiService.saveToken(token);

      // 3. Update FCM Token on backend (Optional/Non-blocking)
      try {
        final fcmToken = await NotificationService().getToken();
        if (fcmToken != null) {
          await _apiService.post('/auth/update-fcm', {
            'fcmToken': fcmToken,
          });
        }
      } catch (e) {
        if (kDebugMode) print('FCM Update failed: $e');
      }

      final user = _mapToEntity(response['data']['user']);
      emit(AuthAuthenticated(user: user, activeRole: user.role));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: _getAuthErrorMessage(e.code)));
    } on ApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(const AuthError(message: 'Terjadi kesalahan. Coba lagi nanti.'));
    }
  }

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // 1. Create user in Firebase Auth
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      final fcmToken = await NotificationService().getToken();

      // 2. Prepare payload for custom Backend API (PostgreSQL)
      final payload = {
        'firebaseUid': credential.user!.uid,
        'email': event.email,
        'name': event.fullName,
        'phone': event.phone,
        'password': event.password, // Backend might still want this for initial setup or custom auth
        'fcmToken': fcmToken,
      };

      if (kDebugMode) {
        print('--- REGISTRATION PAYLOAD ---');
        print(payload);
        print('----------------------------');
      }

      // 3. Send to custom backend
      await _apiService.post('/auth/register', payload);

      emit(const AuthRegistrationSuccess(
        message: 'Registrasi berhasil! Silakan login.',
      ));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: _getAuthErrorMessage(e.code)));
    } on ApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(const AuthError(message: 'Registrasi gagal. Coba lagi nanti.'));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _firebaseAuth.signOut();
    await _apiService.clearToken();
    emit(AuthUnauthenticated());
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

  UserEntity _mapToEntity(Map<String, dynamic> data) {
    return UserModel.fromJson(data);
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Email tidak terdaftar.';
      case 'wrong-password':
        return 'Password salah.';
      case 'email-already-in-use':
        return 'Email sudah digunakan.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah.';
      default:
        return 'Terjadi kesalahan autentikasi.';
    }
  }
}
