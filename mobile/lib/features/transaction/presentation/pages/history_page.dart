import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/services/mock_data_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mock transaction data
    final transactions = MockDataService.dummyTransactions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'OBROLAN TRANSAKSI',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20.0),
        itemCount: isLoading ? 6 : transactions.length,
        itemBuilder: (context, index) {
          if (isLoading) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: BrutalSkeletonCard(),
            );
          }

          final trx = transactions[index];
          // Mock some chat data
          final lastMessage = index % 2 == 0 
              ? "Penjual: Akun sudah siap gan, silakan cek detailnya..." 
              : "Pembeli: Oke, saya proses pembayarannya sekarang.";
          final hasUnread = index < 2;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: BrutalistBounce(
              onTap: () => context.push('/chat-room'),
              child: BrutalistCard(
                padding: const EdgeInsets.all(12),
                shadowOffset: const Offset(6, 6),
                child: Row(
                  children: [
                    // Transaction Icon / Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _getTrxColor(index),
                        border: Border.all(color: AppColors.black, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.black,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.forum_rounded, color: AppColors.black),
                    ),
                    const SizedBox(width: 14),
                    
                    // Chat Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trx['description'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w900, 
                              fontSize: 16,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lastMessage,
                            style: const TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.w600, 
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Trailing: Status + Unread
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildStatusBadge(trx['status']),
                        if (hasUnread) ...[
                          const SizedBox(height: 8),
                          _buildUnreadBadge("2"),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getTrxColor(int index) {
    const colors = [
      Color(0xFFB4E600), // Neon Green
      Color(0xFFFFD54F), // Mustard Yellow
      Color(0xFF81D4FA), // Bright Blue
      Color(0xFFF48FB1), // Hot Pink
    ];
    return colors[index % colors.length];
  }

  Widget _buildUnreadBadge(String count) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF2E63), // Bright Pink/Red
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.black, width: 2),
      ),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      child: Center(
        child: Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    Color textColor = AppColors.black;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'DONE':
        color = AppColors.success;
        label = 'SELESAI';
        break;
      case 'DISPUTED':
        color = AppColors.error;
        label = 'DISPUTE';
        textColor = Colors.white;
        break;
      case 'AWAITING_PAYMENT':
        color = const Color(0xFF673AB7); // Deep Purple
        label = 'BELUM BAYAR';
        textColor = Colors.white;
        break;
      case 'ESCROW':
        color = const Color(0xFF2196F3); // Blue
        label = 'DITAHAN';
        textColor = Colors.white;
        break;
      default:
        color = AppColors.primary;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.black, width: 2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8, 
          fontWeight: FontWeight.w900, 
          color: textColor,
        ),
      ),
    );
  }
}


