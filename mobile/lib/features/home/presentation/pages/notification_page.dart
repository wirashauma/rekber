import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../notification/domain/entities/notification_entity.dart';
import '../../../notification/presentation/cubit/notification_cubit.dart';
import '../../../notification/presentation/cubit/notification_state.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationCubit>().loadNotifications(refresh: true);
    });
  }

  void _handleNotificationTap(NotificationEntity notif) {
    if (!notif.isRead) {
      context.read<NotificationCubit>().markAsRead(notif.id);
    }

    final targetRoute = NotificationService.resolveRouteFromPayload(notif.data);
    if (targetRoute != null && mounted) {
      context.push(targetRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.black, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'NOTIFIKASI',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          BlocBuilder<NotificationCubit, NotificationState>(
            builder: (context, state) {
              final unreadCount = state is NotificationLoaded
                  ? state.unreadCount
                  : context.read<NotificationCubit>().unreadCount;

              if (unreadCount == 0) return const SizedBox.shrink();

              return TextButton(
                onPressed: () {
                  context.read<NotificationCubit>().markAllAsRead();
                },
                child: const Text(
                  'BACA SEMUA',
                  style: TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(
            color: AppColors.black,
            height: 4.0,
          ),
        ),
      ),
      body: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading) {
            return ListView.separated(
              padding: const EdgeInsets.all(24.0),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, __) => const BrutalSkeleton(
                width: double.infinity,
                height: 100,
                borderRadius: 0,
              ),
            );
          }

          if (state is NotificationError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    BrutalistButton(
                      text: 'COBA LAGI',
                      backgroundColor: AppColors.black,
                      textColor: AppColors.white,
                      onPressed: () => context.read<NotificationCubit>().loadNotifications(refresh: true),
                    ),
                  ],
                ),
              ),
            );
          }

          final notifications = state is NotificationLoaded
              ? state.notifications
              : context.read<NotificationCubit>().currentNotifications;

          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => context.read<NotificationCubit>().loadNotifications(refresh: true),
              color: AppColors.black,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(color: AppColors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: AppColors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          const Text(
                            'Belum Ada Notifikasi',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Aktivitas penting terkait transaksi dan sengketa Anda akan muncul di sini.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<NotificationCubit>().loadNotifications(refresh: true),
            color: AppColors.black,
            child: ListView.separated(
              padding: const EdgeInsets.all(24.0),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final style = _getNotificationStyle(notif.type);

                return BrutalistBounce(
                  onTap: () => _handleNotificationTap(notif),
                  child: BrutalistCard(
                    backgroundColor: notif.isRead ? AppColors.white : const Color(0xFFFFFDE7),
                    padding: const EdgeInsets.all(16),
                    shadowOffset: const Offset(4, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: style.bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.black, width: 2),
                          ),
                          child: Icon(style.icon, color: AppColors.black, size: 26),
                        ),
                        const SizedBox(width: 16),

                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif.title,
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (!notif.isRead)
                                    Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(left: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.black, width: 2),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notif.body,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _formatTime(notif.createdAt),
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  _NotifStyle _getNotificationStyle(String type) {
    if (type.contains('DISPUTE')) {
      return _NotifStyle(Icons.warning_amber_rounded, AppColors.error);
    } else if (type.contains('COMPLETED') || type.contains('PAID')) {
      return _NotifStyle(Icons.check_circle_rounded, AppColors.success);
    } else if (type.contains('SHIPPED')) {
      return _NotifStyle(Icons.local_shipping_rounded, AppColors.lightBlue);
    } else if (type.contains('TOPUP') || type.contains('WITHDRAWAL')) {
      return _NotifStyle(Icons.account_balance_wallet_rounded, AppColors.info);
    }
    return _NotifStyle(Icons.notifications_rounded, AppColors.secondary);
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _NotifStyle {
  final IconData icon;
  final Color bgColor;
  _NotifStyle(this.icon, this.bgColor);
}
