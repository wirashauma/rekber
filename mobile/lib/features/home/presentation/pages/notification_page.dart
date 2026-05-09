import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mock notifications list
    final List<Map<String, dynamic>> notifications = [
      {
        'type': 'dana_masuk',
        'title': 'Dana Masuk! 💸',
        'subtitle': 'Pembeli @jagoan_neon sudah transfer Rp450.000 untuk transaksi Beli Akun Valorant.',
        'time': '10 menit yang lalu',
        'isUnread': true,
      },
      {
        'type': 'selesai',
        'title': 'Transaksi Selesai ✅',
        'subtitle': 'Transaksi Jasa GB Rank Mobile Legends telah selesai. Dana diteruskan ke saldo Anda.',
        'time': '2 jam yang lalu',
        'isUnread': true,
      },
      {
        'type': 'dispute',
        'title': 'Transaksi Bermasalah ⚠️',
        'subtitle': 'Pembeli mengajukan komplain untuk transaksi Top Up Discord Nitro 1 Year.',
        'time': '1 hari yang lalu',
        'isUnread': false,
      },
      {
        'type': 'selesai',
        'title': 'Pencairan Berhasil 🏦',
        'subtitle': 'Pencairan dana sebesar Rp1.200.000 ke rekening BCA Anda telah berhasil.',
        'time': '3 hari yang lalu',
        'isUnread': false,
      },
    ];

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(
            color: AppColors.black,
            height: 4.0,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24.0),
        physics: const BouncingScrollPhysics(),
        itemCount: isLoading ? 4 : notifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          if (isLoading) {
            return const BrutalistSkeleton(
              width: double.infinity,
              height: 100,
              borderRadius: 0,
            );
          }

          final notif = notifications[index];
          
          IconData iconData;
          Color iconBgColor;

          switch (notif['type']) {
            case 'dana_masuk':
              iconData = Icons.account_balance_wallet_rounded;
              iconBgColor = AppColors.info;
              break;
            case 'selesai':
              iconData = Icons.check_circle_rounded;
              iconBgColor = AppColors.success;
              break;
            case 'dispute':
              iconData = Icons.warning_rounded;
              iconBgColor = AppColors.error;
              break;
            default:
              iconData = Icons.notifications_rounded;
              iconBgColor = AppColors.secondary;
          }

          return BrutalistBounce(
            onTap: () {},
            child: BrutalistCard(
              backgroundColor: AppColors.white,
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
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.black, width: 2),
                    ),
                    child: Icon(iconData, color: AppColors.black, size: 28),
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
                                notif['title'],
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (notif['isUnread'] == true)
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.accent, // Neon Green
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.black, width: 2),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notif['subtitle'],
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          notif['time'],
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
  }
}
