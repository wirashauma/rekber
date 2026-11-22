import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/admin_repository.dart';
import 'admin_state.dart';

class AdminCubit extends Cubit<AdminState> {
  final AdminRepository _adminRepository;

  AdminCubit({required AdminRepository adminRepository})
      : _adminRepository = adminRepository,
        super(const AdminInitial());

  bool _isForbidden(String message) {
    return message.toLowerCase().contains('akses ditolak') ||
        message.toLowerCase().contains('administrator') ||
        message.contains('403');
  }

  // ── 1. Metrics & Dashboard ──
  Future<void> loadDashboardMetrics() async {
    emit(const AdminLoading(message: 'Memuat data analitik...'));
    final result = await _adminRepository.getMetrics();
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (metrics) => emit(AdminDashboardLoaded(metrics: metrics)),
    );
  }

  // ── 2. Disputes Moderation ──
  Future<void> loadDisputes({String status = 'Semua', int page = 1}) async {
    emit(const AdminLoading(message: 'Memuat daftar sengketa...'));
    final result = await _adminRepository.getDisputes(
      status: status == 'Semua' ? null : status,
      page: page,
    );
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (data) {
        final list = (data['data'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        final pagination = data['pagination'] as Map<String, dynamic>?;
        emit(AdminDisputesLoaded(
          disputes: list,
          statusFilter: status,
          pagination: pagination,
        ));
      },
    );
  }

  Future<void> reviewDispute(String id, {String currentFilter = 'Semua'}) async {
    emit(const AdminLoading(message: 'Memproses review sengketa...'));
    final result = await _adminRepository.reviewDispute(id);
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (_) {
        emit(const AdminActionSuccess(message: 'Status sengketa diubah menjadi SEDANG DITINJAU.'));
        loadDisputes(status: currentFilter);
      },
    );
  }

  Future<void> resolveDispute({
    required String id,
    required String decision,
    required String note,
    String currentFilter = 'Semua',
  }) async {
    if (note.trim().length < 10) {
      emit(const AdminError(message: 'Catatan putusan minimal 10 karakter.'));
      return;
    }

    emit(const AdminLoading(message: 'Menyelesaikan sengketa...'));
    final result = await _adminRepository.resolveDispute(
      id,
      decision: decision,
      note: note.trim(),
    );
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (_) {
        emit(const AdminActionSuccess(message: 'Sengketa berhasil diputuskan & diselesaikan.'));
        loadDisputes(status: currentFilter);
      },
    );
  }

  // ── 3. KYC Verification ──
  Future<void> loadKycSubmissions({String status = 'PENDING'}) async {
    emit(const AdminLoading(message: 'Memuat antrian KYC...'));
    final result = await _adminRepository.getKycSubmissions(
      status: status == 'Semua' ? null : status,
    );
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (data) {
        final list = (data['data'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        emit(AdminKycLoaded(
          submissions: list,
          statusFilter: status,
          nextCursor: data['nextCursor'] as String?,
          hasMore: (data['hasMore'] as bool?) ?? false,
        ));
      },
    );
  }

  Future<void> approveKyc(String id, {String currentFilter = 'PENDING'}) async {
    emit(const AdminLoading(message: 'Menyetujui KYC...'));
    final result = await _adminRepository.approveKyc(id);
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (_) {
        emit(const AdminActionSuccess(message: 'Pengajuan KYC berhasil disetujui.'));
        loadKycSubmissions(status: currentFilter);
      },
    );
  }

  Future<void> rejectKyc({
    required String id,
    required String reason,
    String currentFilter = 'PENDING',
  }) async {
    if (reason.trim().length < 5) {
      emit(const AdminError(message: 'Alasan penolakan minimal 5 karakter.'));
      return;
    }

    emit(const AdminLoading(message: 'Menolak KYC...'));
    final result = await _adminRepository.rejectKyc(id, reason: reason.trim());
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (_) {
        emit(const AdminActionSuccess(message: 'Pengajuan KYC berhasil ditolak.'));
        loadKycSubmissions(status: currentFilter);
      },
    );
  }

  // ── 4. Users Management ──
  Future<void> loadUsers({String search = '', String? status}) async {
    emit(const AdminLoading(message: 'Memuat data pengguna...'));
    final result = await _adminRepository.getUsers(
      search: search.isEmpty ? null : search,
      status: status,
    );
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (data) {
        final list = (data['data'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        emit(AdminUsersLoaded(
          users: list,
          searchQuery: search,
          nextCursor: data['nextCursor'] as String?,
          hasMore: (data['hasMore'] as bool?) ?? false,
        ));
      },
    );
  }

  Future<void> banUser(String id, {required String reason, String currentSearch = ''}) async {
    if (reason.trim().length < 3) {
      emit(const AdminError(message: 'Alasan blokir minimal 3 karakter.'));
      return;
    }

    emit(const AdminLoading(message: 'Memblokir pengguna...'));
    final result = await _adminRepository.banUser(id, reason: reason.trim());
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (_) {
        emit(const AdminActionSuccess(message: 'Pengguna berhasil diblokir.'));
        loadUsers(search: currentSearch);
      },
    );
  }

  Future<void> unbanUser(String id, {String currentSearch = ''}) async {
    emit(const AdminLoading(message: 'Membuka blokir pengguna...'));
    final result = await _adminRepository.unbanUser(id);
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (_) {
        emit(const AdminActionSuccess(message: 'Blokir pengguna berhasil dibuka.'));
        loadUsers(search: currentSearch);
      },
    );
  }

  // ── 5. Platform Financial Settings ──
  Future<void> loadSettings() async {
    emit(const AdminLoading(message: 'Memuat pengaturan...'));
    final result = await _adminRepository.getSettings();
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (settings) => emit(AdminSettingsLoaded(settings: settings)),
    );
  }

  Future<void> updateSetting(String key, dynamic value) async {
    emit(const AdminLoading(message: 'Menyimpan pengaturan...'));
    final result = await _adminRepository.updateSetting(key, value);
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (_) {
        emit(AdminActionSuccess(message: 'Pengaturan $key berhasil diperbarui.'));
        loadSettings();
      },
    );
  }

  // ── 6. Audit Logs ──
  Future<void> loadAuditLogs() async {
    emit(const AdminLoading(message: 'Memuat log audit...'));
    final result = await _adminRepository.getAuditLogs();
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (data) {
        final list = (data['data'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        emit(AdminAuditLogsLoaded(
          logs: list,
          nextCursor: data['nextCursor'] as String?,
          hasMore: (data['hasMore'] as bool?) ?? false,
        ));
      },
    );
  }

  // ── 7. Withdrawals Approval ──
  Future<void> loadWithdrawals({String status = 'PENDING_REVIEW'}) async {
    emit(const AdminLoading(message: 'Memuat permintaan penarikan...'));
    final result = await _adminRepository.getWithdrawals(
      status: status == 'Semua' ? null : status,
    );
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (data) {
        final list = (data['withdrawals'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        emit(AdminWithdrawalsLoaded(
          withdrawals: list,
          statusFilter: status,
          nextCursor: data['nextCursor'] as String?,
        ));
      },
    );
  }

  Future<void> approveWithdrawal(String id, {String currentFilter = 'PENDING_REVIEW'}) async {
    emit(const AdminLoading(message: 'Menyetujui penarikan dana...'));
    final result = await _adminRepository.approveWithdrawal(id);
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (_) {
        emit(const AdminActionSuccess(message: 'Penarikan dana disetujui & diproses ke penyedia.'));
        loadWithdrawals(status: currentFilter);
      },
    );
  }

  Future<void> rejectWithdrawal({
    required String id,
    required String reason,
    String currentFilter = 'PENDING_REVIEW',
  }) async {
    if (reason.trim().length < 5) {
      emit(const AdminError(message: 'Alasan penolakan penarikan minimal 5 karakter.'));
      return;
    }

    emit(const AdminLoading(message: 'Menolak permintaan penarikan...'));
    final result = await _adminRepository.rejectWithdrawal(id, reason: reason.trim());
    result.fold(
      (failure) => emit(AdminError(
        message: failure.message,
        isForbidden: _isForbidden(failure.message),
      )),
      (_) {
        emit(const AdminActionSuccess(message: 'Permintaan penarikan berhasil ditolak & saldo dikembalikan.'));
        loadWithdrawals(status: currentFilter);
      },
    );
  }
}
