import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../cubit/wallet_cubit.dart';
import '../cubit/wallet_state.dart';
import '../../domain/entities/bank_account_entity.dart';
import '../../domain/entities/withdrawal_entity.dart';

class TarikDanaScreen extends StatefulWidget {
  const TarikDanaScreen({super.key});

  @override
  State<TarikDanaScreen> createState() => _TarikDanaScreenState();
}

class _TarikDanaScreenState extends State<TarikDanaScreen> {
  final TextEditingController _amountController = TextEditingController();
  String? _selectedBankAccountId;

  final List<String> _bankCodes = ['BCA', 'MANDIRI', 'BRI', 'BNI', 'PERMATA', 'CIMB'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletCubit>().loadWalletData();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showAddBankAccountModal() {
    final bankCodeCtrl = ValueNotifier<String>(_bankCodes.first);
    final accNumberCtrl = TextEditingController();
    final accNameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.black, width: 3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TAMBAH REKENING BANK',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 16),
              const Text('Pilih Bank', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ValueListenableBuilder<String>(
                valueListenable: bankCodeCtrl,
                builder: (_, currentBank, __) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentBank,
                      isExpanded: true,
                      items: _bankCodes.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (val) {
                        if (val != null) bankCodeCtrl.value = val;
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Nomor Rekening', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              BrutalistTextField(
                controller: accNumberCtrl,
                hintText: 'Masukkan nomor rekening',
                prefixIcon: Icons.credit_card_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              const Text('Nama Pemilik Rekening (Sesuai KTP)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              BrutalistTextField(
                controller: accNameCtrl,
                hintText: 'Nama lengkap sesuai buku tabungan',
                prefixIcon: Icons.person_rounded,
              ),
              const SizedBox(height: 24),
              BrutalistButton(
                text: 'SIMPAN REKENING',
                backgroundColor: AppColors.tealGreen,
                textColor: Colors.black,
                onPressed: () {
                  final num = accNumberCtrl.text.trim();
                  final name = accNameCtrl.text.trim();
                  if (num.isEmpty || name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Semua field wajib diisi.')),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop();
                  context.read<WalletCubit>().addBankAccount(
                        bankCode: bankCodeCtrl.value,
                        accountNumber: num,
                        accountName: name,
                      );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitWithdrawal() {
    if (_selectedBankAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih rekening bank tujuan terlebih dahulu.')),
      );
      return;
    }

    final amount = int.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount < 50000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batas minimal penarikan dana adalah Rp 50.000.')),
      );
      return;
    }

    final walletState = context.read<WalletCubit>().state;
    if (walletState is WalletLoaded && walletState.summary.balance < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saldo Anda tidak mencukupi (Saldo saat ini: ${CurrencyFormatter.format(walletState.summary.balance)}).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Penarikan'),
        content: Text(
          'Tarik dana sebesar ${CurrencyFormatter.format(amount)} ke rekening terpilih?\nPenarikan akan ditinjau oleh Admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealGreen),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<WalletCubit>().submitWithdrawal(
                    bankAccountId: _selectedBankAccountId!,
                    amount: amount,
                  );
            },
            child: const Text('Ya, Tarik Sekarang', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletCubit, WalletState>(
      listener: (context, state) {
        if (state is WalletActionFailure) {
          if (state.isKycRequired) {
            _showKycRequiredDialog(state.message);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } else if (state is WalletActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is WalletLoading || state is WalletActionLoading;

        int availableBalance = 0;
        List<BankAccountEntity> bankAccounts = [];
        List<WithdrawalEntity> withdrawals = [];

        if (state is WalletLoaded) {
          availableBalance = state.summary.balance;
          bankAccounts = state.bankAccounts;
          withdrawals = state.withdrawals;
        }

        if (_selectedBankAccountId == null && bankAccounts.isNotEmpty) {
          _selectedBankAccountId = bankAccounts.first.id;
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: AppColors.tealGreen,
            elevation: 0,
            title: Text(
              'TARIK DANA (WITHDRAW)',
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Saldo Tersedia
                BrutalistCard(
                  backgroundColor: AppColors.paleYellow,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Saldo Tersedia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            CurrencyFormatter.format(availableBalance),
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.account_balance_wallet_rounded, size: 36, color: Colors.black),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Manajemen Rekening Bank
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rekening Bank Tujuan',
                      style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16, color: Colors.black),
                      label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                      onPressed: _showAddBankAccountModal,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (bankAccounts.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 2),
                      color: Colors.grey.shade50,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Text('Belum ada rekening bank yang tersimpan.', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _showAddBankAccountModal,
                            child: const Text('Tambah Rekening Sekarang', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.tealGreen)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  ...bankAccounts.map((acc) {
                    final isSelected = _selectedBankAccountId == acc.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedBankAccountId = acc.id),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.tealGreen.withValues(alpha: 0.2) : Colors.white,
                            border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade400, width: isSelected ? 2.5 : 1.5),
                          ),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: acc.id,
                                groupValue: _selectedBankAccountId,
                                activeColor: Colors.black,
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedBankAccountId = val);
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${acc.bankCode} • ${acc.maskedNumber}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                    ),
                                    Text(
                                      'a.n. ${acc.accountName}',
                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                onPressed: () {
                                  context.read<WalletCubit>().deleteBankAccount(acc.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 24),

                // Input Nominal Penarikan
                Text(
                  'Nominal Penarikan (Rp)',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 8),
                BrutalistTextField(
                  hintText: 'Minimal Rp 50.000',
                  prefixIcon: Icons.payments_rounded,
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Batas penarikan: Min. Rp 50.000 | Biaya: Rp 0 | Maks. Rp 10.000.000 / hari',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 28),

                BrutalistButton(
                  text: isLoading ? 'MEMPROSES...' : 'TARIK DANA SEKARANG',
                  backgroundColor: AppColors.tealGreen,
                  textColor: Colors.black,
                  onPressed: isLoading ? () {} : _submitWithdrawal,
                ),
                const SizedBox(height: 40),

                // Riwayat Penarikan
                Text(
                  'Riwayat Penarikan Dana',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 12),

                if (withdrawals.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: Text('Belum ada riwayat penarikan.')),
                  ),
                ] else ...[
                  ...withdrawals.map((w) {
                    final canCancel = w.canCancel;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: BrutalistCard(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CurrencyFormatter.format(w.amount),
                                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${w.createdAt.day}/${w.createdAt.month}/${w.createdAt.year} • Status: ${w.status}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                                if (w.failureReason != null)
                                  Text(
                                    'Alasan: ${w.failureReason}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.error),
                                  ),
                              ],
                            ),
                            if (canCancel)
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.black, width: 1.5),
                                ),
                                onPressed: () {
                                  context.read<WalletCubit>().cancelWithdrawal(w.id);
                                },
                                child: const Text('Batalkan', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showKycRequiredDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verifikasi KYC Diperlukan'),
        content: Text(
          '$message\n\nUntuk menjaga keamanan dan mematuhi regulasi perbankan, penarikan dana hanya dapat dilakukan setelah akun Anda memiliki status KYC APPROVED.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nanti Saja'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealGreen),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/kyc');
            },
            child: const Text('Verifikasi Sekarang', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
