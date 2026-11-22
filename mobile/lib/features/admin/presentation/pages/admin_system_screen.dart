import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class AdminSystemScreen extends StatefulWidget {
  const AdminSystemScreen({super.key});

  @override
  State<AdminSystemScreen> createState() => _AdminSystemScreenState();
}

class _AdminSystemScreenState extends State<AdminSystemScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadAuditLogs();
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
          'LOG AUDIT SISTEM',
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
      body: BlocConsumer<AdminCubit, AdminState>(
        listener: (context, state) {
          if (state is AdminError) {
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
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  BrutalSkeleton(width: double.infinity, height: 80),
                  SizedBox(height: 12),
                  BrutalSkeleton(width: double.infinity, height: 80),
                  SizedBox(height: 12),
                  BrutalSkeleton(width: double.infinity, height: 80),
                ],
              ),
            );
          }

          final logsLoaded = state is AdminAuditLogsLoaded ? state : null;
          final logs = logsLoaded?.logs ?? [];

          if (logs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => context.read<AdminCubit>().loadAuditLogs(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_rounded, size: 56, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'Belum Ada Catatan Audit',
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
            onRefresh: () => context.read<AdminCubit>().loadAuditLogs(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                return _buildAuditLogCard(logs[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAuditLogCard(Map<String, dynamic> log) {
    final action = log['action']?.toString() ?? 'SYSTEM_EVENT';
    final targetType = log['targetType']?.toString() ?? '-';
    final targetId = log['targetId']?.toString() ?? '-';
    final ip = log['ip']?.toString() ?? '127.0.0.1';
    final createdAt = log['createdAt']?.toString() ?? '-';
    final before = log['before'];
    final after = log['after'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: BrutalistCard(
        backgroundColor: AppColors.white,
        padding: const EdgeInsets.all(14),
        borderRadius: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BrutalistBadge(
                  text: action,
                  backgroundColor: _getActionBadgeColor(action),
                ),
                Text(
                  ip,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Target: $targetType ($targetId)',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Waktu: $createdAt',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            if (before != null || after != null) ...[
              const SizedBox(height: 8),
              Theme(
                data: ThemeData().copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.all(8),
                  title: Text(
                    'Detail Perubahan (JSON)',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brightBlue,
                    ),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey[100],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (before != null) ...[
                            Text('BEFORE:',
                                style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold)),
                            Text('$before',
                                style: GoogleFonts.spaceMono(fontSize: 9, color: Colors.red[800])),
                            const SizedBox(height: 6),
                          ],
                          if (after != null) ...[
                            Text('AFTER:',
                                style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold)),
                            Text('$after',
                                style: GoogleFonts.spaceMono(fontSize: 9, color: Colors.green[800])),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getActionBadgeColor(String action) {
    if (action.contains('APPROVE') || action.contains('RESOLVE')) {
      return AppColors.tealGreen;
    }
    if (action.contains('REJECT') || action.contains('BAN')) {
      return Colors.redAccent;
    }
    if (action.contains('UPDATE') || action.contains('REVIEW')) {
      return Colors.orangeAccent;
    }
    return Colors.yellowAccent;
  }
}
