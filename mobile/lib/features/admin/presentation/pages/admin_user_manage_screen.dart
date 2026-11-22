import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class AdminUserManageScreen extends StatefulWidget {
  const AdminUserManageScreen({super.key});

  @override
  State<AdminUserManageScreen> createState() => _AdminUserManageScreenState();
}

class _AdminUserManageScreenState extends State<AdminUserManageScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    context.read<AdminCubit>().loadUsers(search: _searchController.text.trim());
  }

  void _showBanDialog(BuildContext context, String userId, String userName) {
    final cubit = context.read<AdminCubit>();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.black, width: 3),
        ),
        title: Text(
          'BLOKIR PENGGUNA',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apakah Anda yakin ingin memblokir akses $userName? Pengguna ini tidak akan bisa login kembali.',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 2,
                style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold),
                validator: (val) {
                  final text = (val ?? '').trim();
                  if (text.isEmpty) return 'Alasan pemblokiran wajib diisi.';
                  if (text.length < 3) return 'Alasan minimal 3 karakter.';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Alasan pemblokiran...',
                  hintStyle: GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.grey),
                  filled: true,
                  fillColor: AppColors.white,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.black, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'BATAL',
              style: GoogleFonts.spaceGrotesk(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          BrutalistButton(
            text: 'YA, BLOKIR',
            backgroundColor: AppColors.black,
            textColor: AppColors.white,
            height: 40,
            width: 120,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final reason = reasonController.text.trim();
                Navigator.pop(ctx);
                cubit.banUser(
                      userId,
                      reason: reason,
                      currentSearch: _searchController.text.trim(),
                    );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showUnbanConfirmation(BuildContext context, String userId, String userName) {
    final cubit = context.read<AdminCubit>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.black, width: 3),
        ),
        title: Text(
          'BUKA BLOKIR PENGGUNA',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: Text(
          'Buka kembali akses untuk "$userName"? Pengguna ini akan dapat login dan bertransaksi kembali.',
          style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'BATAL',
              style: GoogleFonts.spaceGrotesk(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          BrutalistButton(
            text: 'BUKA BLOKIR',
            backgroundColor: AppColors.tealGreen,
            textColor: AppColors.white,
            height: 40,
            width: 130,
            onPressed: () {
              Navigator.pop(ctx);
              cubit.unbanUser(
                    userId,
                    currentSearch: _searchController.text.trim(),
                  );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'KELOLA PENGGUNA',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: AppColors.black, height: 2),
        ),
      ),
      body: Column(
        children: [
          // ── SEARCH BAR ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: BrutalistTextField(
                    controller: _searchController,
                    hintText: 'Cari nama atau email...',
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                BrutalistBounce(
                  onTap: _onSearch,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      border: Border.all(color: AppColors.black, width: 2),
                    ),
                    child: const Icon(Icons.search, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // ── USERS LIST ──
          Expanded(
            child: BlocConsumer<AdminCubit, AdminState>(
              listener: (context, state) {
                if (state is AdminActionSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.tealGreen,
                    ),
                  );
                } else if (state is AdminError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is AdminLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        BrutalSkeleton(width: double.infinity, height: 70),
                        SizedBox(height: 12),
                        BrutalSkeleton(width: double.infinity, height: 70),
                        SizedBox(height: 12),
                        BrutalSkeleton(width: double.infinity, height: 70),
                      ],
                    ),
                  );
                }

                final usersLoaded = state is AdminUsersLoaded ? state : null;
                final users = usersLoaded?.users ?? [];

                if (users.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => _onSearch(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                'Pengguna Tidak Ditemukan',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _onSearch(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(context, users[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final name = user['name']?.toString() ?? 'Tanpa Nama';
    final email = user['email']?.toString() ?? '-';
    final role = user['role']?.toString() ?? 'USER';
    final isActive = (user['isActive'] as bool?) ?? true;
    final kycStatus = user['kycStatus']?.toString() ?? 'NONE';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: BrutalistCard(
        backgroundColor: AppColors.white,
        padding: const EdgeInsets.all(14),
        borderRadius: 4,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isActive ? Colors.blue[100] : Colors.grey[300],
              radius: 20,
              child: Icon(
                isActive ? Icons.person : Icons.person_off_rounded,
                color: isActive ? AppColors.black : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (role == 'ADMIN') ...[
                        const SizedBox(width: 6),
                        const BrutalistBadge(text: 'ADMIN', backgroundColor: Colors.amberAccent),
                      ],
                    ],
                  ),
                  Text(
                    email,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'KYC: $kycStatus',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: kycStatus == 'APPROVED' ? AppColors.tealGreen : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isActive ? 'AKTIF' : 'DIBLOKIR',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isActive ? Colors.green[800] : Colors.red[800],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (role != 'ADMIN')
              isActive
                  ? BrutalistButton(
                      text: 'BAN',
                      backgroundColor: Colors.redAccent,
                      textColor: Colors.white,
                      height: 34,
                      width: 64,
                      borderRadius: 4,
                      onPressed: () => _showBanDialog(context, userId, name),
                    )
                  : BrutalistButton(
                      text: 'UNBAN',
                      backgroundColor: AppColors.tealGreen,
                      textColor: Colors.white,
                      height: 34,
                      width: 74,
                      borderRadius: 4,
                      onPressed: () => _showUnbanConfirmation(context, userId, name),
                    ),
          ],
        ),
      ),
    );
  }
}
