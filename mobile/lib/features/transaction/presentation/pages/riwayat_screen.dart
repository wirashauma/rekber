import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../data/models/transaction_model.dart';
import '../../../../injection_container.dart';
import '../../../../core/services/api_service.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  bool isLoading = true;
  List<TransactionEntity> riwayat = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final response = await sl<ApiService>().get('/transactions');
      if (response != null && response['data'] != null) {
        final List<dynamic> data = response['data'];
        setState(() {
          riwayat = data.map((e) => TransactionModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'RIWAYAT TRANSAKSI',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const Border(
          bottom: BorderSide(color: Colors.black, width: 2.0),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: isLoading ? 5 : riwayat.length,
        itemBuilder: (context, index) {
          if (isLoading) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: BrutalSkeletonCard(),
            );
          }

          final item = riwayat[index];
          final isCompleted = item.status == 'completed';
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: BrutalistCard(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.success : AppColors.error,
                      border: Border.all(color: Colors.black, width: 2.0),
                    ),
                    child: Icon(
                      isCompleted 
                        ? Icons.check_circle_outline_rounded 
                        : Icons.cancel_outlined,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description ?? 'Tanpa Deskripsi',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(item.amount),
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCompleted ? AppColors.success : AppColors.error,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: Text(
                          item.status.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
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

