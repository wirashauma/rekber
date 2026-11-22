import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../cubit/transaction_cubit.dart';
import '../cubit/transaction_state.dart';
import '../../domain/services/escrow_state_machine.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionCubit>().loadTransactions();
    });
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
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        shape: const Border(
          bottom: BorderSide(color: Colors.black, width: 2.0),
        ),
      ),
      body: BlocBuilder<TransactionCubit, TransactionState>(
        builder: (context, state) {
          if (state is TransactionLoading) {
            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: 5,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: BrutalSkeletonCard(),
              ),
            );
          }

          if (state is TransactionError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: BrutalistCard(
                  backgroundColor: AppColors.paleYellow,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      BrutalistButton(
                        text: 'COBA LAGI',
                        backgroundColor: AppColors.black,
                        textColor: AppColors.white,
                        onPressed: () => context.read<TransactionCubit>().loadTransactions(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final transactions = (state is TransactionListLoaded)
              ? state.transactions
              : context.read<TransactionCubit>().currentList;

          if (transactions.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => context.read<TransactionCubit>().loadTransactions(),
              color: AppColors.black,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_outlined, size: 64, color: AppColors.textSecondary),
                          const SizedBox(height: 16),
                          Text(
                            'Belum Ada Riwayat Transaksi',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Transaksi yang Anda buat atau ikuti akan muncul di sini.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
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
            onRefresh: () => context.read<TransactionCubit>().loadTransactions(),
            color: AppColors.black,
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final item = transactions[index];
                final statusColor = AppColors.getStatusColor(item.status);
                final statusLabel = EscrowStateMachine.getStatusLabel(item.status);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: BrutalistBounce(
                    onTap: () => context.push('/transaction/${item.id}'),
                    child: BrutalistCard(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: statusColor,
                              border: Border.all(color: Colors.black, width: 2.0),
                            ),
                            child: const Icon(
                              Icons.receipt_rounded,
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
                                const SizedBox(height: 4),
                                Text(
                                  '${item.txCode} • ${item.createdAt.day.toString().padLeft(2, '0')}/${item.createdAt.month.toString().padLeft(2, '0')}/${item.createdAt.year}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.black.withValues(alpha: 0.6),
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
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  border: Border.all(color: Colors.black, width: 1.5),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
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
        },
      ),
    );
  }
}
