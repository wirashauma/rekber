import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../cubit/wallet_cubit.dart';
import '../cubit/wallet_state.dart';
import '../../domain/entities/ledger_entry_entity.dart';

class MutasiScreen extends StatefulWidget {
  const MutasiScreen({super.key});

  @override
  State<MutasiScreen> createState() => _MutasiScreenState();
}

class _MutasiScreenState extends State<MutasiScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletCubit>().loadWalletData();
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
          'MUTASI BUKU BESAR',
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
        shape: const Border(bottom: BorderSide(color: Colors.black, width: 2.0)),
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) {
          if (state is WalletLoading) {
            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: 5,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: BrutalSkeletonCard(),
              ),
            );
          }

          List<LedgerEntryEntity> entries = [];
          if (state is WalletLoaded) {
            entries = state.ledgerEntries;
          }

          if (entries.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => context.read<WalletCubit>().loadWalletData(),
              color: Colors.black,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Belum Ada Mutasi Saldo',
                          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Setiap perpindahan saldo dan transaksi akan tercatat di sini secara transparan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<WalletCubit>().loadWalletData(),
            color: Colors.black,
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isCredit = entry.isCredit;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: BrutalistCard(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isCredit ? AppColors.tealGreen : AppColors.error.withValues(alpha: 0.2),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Icon(
                            isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: isCredit ? Colors.black : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCredit ? 'Saldo Masuk (Kredit)' : 'Saldo Keluar (Debit)',
                                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entry.createdAt.day.toString().padLeft(2, '0')}/${entry.createdAt.month.toString().padLeft(2, '0')}/${entry.createdAt.year} ${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                              if (entry.referenceType != null)
                                Text(
                                  'Ref: ${entry.referenceType}',
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isCredit ? '+' : '-'}${CurrencyFormatter.format(entry.amount)}',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: isCredit ? AppColors.tealGreen : AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sisa: ${CurrencyFormatter.format(entry.balanceAfter)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
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
        },
      ),
    );
  }
}
