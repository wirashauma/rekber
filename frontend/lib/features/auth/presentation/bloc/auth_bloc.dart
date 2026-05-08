import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../domain/entities/user_entity.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Auth BLoC — Manages authentication state and role switching
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseClient _supabase;

  AuthBloc({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient,
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

    final session = _supabase.auth.currentSession;
    if (session == null) {
      emit(AuthUnauthenticated());
      return;
    }

    try {
      final userData = await _supabase
          .from('users')
          .select()
          .eq('id', session.user.id)
          .single();

      final user = _mapToEntity(userData);
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
      final response = await _supabase.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );

      if (response.user == null) {
        emit(const AuthError(message: 'Login gagal. Periksa email dan password.'));
        return;
      }

      // Fetch user profile
      final userData = await _supabase
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .single();

      final user = _mapToEntity(userData);
      emit(AuthAuthenticated(user: user, activeRole: user.role));
    } on AuthException catch (e) {
      emit(AuthError(message: _getAuthErrorMessage(e.message)));
    } catch (e) {
      emit(AuthError(message: 'Terjadi kesalahan. Coba lagi nanti.'));
    }
  }

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final response = await _supabase.auth.signUp(
        email: event.email,
        password: event.password,
        data: {
          'full_name': event.fullName,
          'phone': event.phone,
        },
      );

      if (response.user == null) {
        emit(const AuthError(message: 'Registrasi gagal.'));
        return;
      }

      // Create user profile in public.users table
      await _supabase.from('users').insert({
        'id': response.user!.id,
        'email': event.email,
        'full_name': event.fullName,
        'phone': event.phone,
        'role': 'buyer', // Default role
      });

      emit(const AuthRegistrationSuccess(
        message: 'Registrasi berhasil! Silakan cek email untuk verifikasi.',
      ));
    } on AuthException catch (e) {
      emit(AuthError(message: _getAuthErrorMessage(e.message)));
    } catch (e) {
      emit(AuthError(message: 'Registrasi gagal. Coba lagi nanti.'));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _supabase.auth.signOut();
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
    return UserEntity(
      id: data['id'],
      email: data['email'],
      fullName: data['full_name'] ?? '',
      phone: data['phone'],
      avatarUrl: data['avatar_url'],
      role: data['role'] ?? 'buyer',
      kycStatus: data['kyc_status'] ?? 'none',
      idCardUrl: data['id_card_url'],
      selfieUrl: data['selfie_url'],
      isActive: data['is_active'] ?? true,
      createdAt: DateTime.parse(data['created_at']),
    );
  }

  String _getAuthErrorMessage(String error) {
    if (error.contains('Invalid login')) {
      return 'Email atau password salah.';
    }
    if (error.contains('Email not confirmed')) {
      return 'Email belum diverifikasi. Cek inbox Anda.';
    }
    if (error.contains('already registered')) {
      return 'Email sudah terdaftar. Silakan login.';
    }
    return 'Terjadi kesalahan: $error';
  }
}
