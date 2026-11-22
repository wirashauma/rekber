import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../injection_container.dart';
import '../../../../core/services/api_service.dart';
import '../cubit/transaction_cubit.dart';
import '../cubit/transaction_state.dart';
import '../../data/models/public_config_model.dart';

class BuatRoomScreen extends StatefulWidget {
  const BuatRoomScreen({super.key});

  @override
  State<BuatRoomScreen> createState() => _BuatRoomScreenState();
}

class _BuatRoomScreenState extends State<BuatRoomScreen> {
  String _peran = 'Penjual'; // Penjual, Pembeli
  String _feePayer = 'SPLIT'; // BUYER, SELLER, SPLIT
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _opponentController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  int _nominal = 0;
  int _fee = 0;
  PublicConfigModel? _config;

  final List<String> _categories = [
    'Akun Game',
    'Item Game',
    'Jasa Joki',
    'Sparepart Motor',
    'Alat Elektronik',
    'Jasa Desain',
    'Pakaian/Sepatu',
    'Lainnya'
  ];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateCalculations);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
    });
  }

  Future<void> _loadConfig() async {
    final cfg = await context.read<TransactionCubit>().loadPublicConfig();
    if (mounted) {
      setState(() {
        _config = cfg;
        _updateCalculations();
      });
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateCalculations);
    _amountController.dispose();
    _opponentController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _updateCalculations() {
    final parsed = int.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    setState(() {
      _nominal = parsed;
      if (_config != null) {
        _fee = _config!.calculateFee(_nominal);
      } else {
        final calc = (_nominal * 0.02).ceil();
        _fee = calc < 1000 ? 1000 : calc;
      }
    });
  }

  Future<void> _createRoom() async {
    final opponentInput = _opponentController.text.trim();
    final descInput = _descController.text.trim();

    if (_nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal transaksi wajib diisi dan minimal Rp 1.000.')),
      );
      return;
    }
    if (opponentInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email atau username lawan transaksi wajib diisi.')),
      );
      return;
    }
    if (descInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori/deskripsi barang wajib diisi.')),
      );
      return;
    }

    // Resolusi lawan transaksi via API
    try {
      final apiService = sl<ApiService>();
      final searchRes = await apiService.get('/auth/search-opponent?query=$opponentInput');
      if (searchRes == null || searchRes['data'] == null || (searchRes['data'] as List).isEmpty) {
        throw ApiException(statusCode: 404, message: 'Lawan transaksi tidak ditemukan.');
      }

      final opponentId = searchRes['data'][0]['id']?.toString();

      if (!mounted) return;
      final txCubit = context.read<TransactionCubit>();
      final success = await txCubit.createTransaction(
            amount: _nominal,
            itemDescription: descInput,
            feePayer: _feePayer,
            sellerId: _peran == 'Pembeli' ? opponentId : null,
            buyerId: _peran == 'Penjual' ? opponentId : null,
          );

      if (!mounted) return;
      if (success) {
        final tx = txCubit.currentDetail;
        _showSuccessDialog(tx?.txCode ?? 'SUKSES', tx?.id ?? '');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat transaksi: ${e.message}', style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan koneksi.', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccessDialog(String code, String txId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: BrutalistCard(
          backgroundColor: AppColors.mustardYellow,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'RUANG REKBER DIBUAT! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bagikan kode unik ini ke lawan transaksi Anda:',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kode disalin ke clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              BrutalistButton(
                text: 'LIHAT DETAIL TRANSAKSI',
                backgroundColor: Colors.black,
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (txId.isNotEmpty) {
                    context.push('/transaction/$txId');
                  } else {
                    context.go('/home');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buyerFee = _feePayer == 'BUYER' ? _fee : (_feePayer == 'SPLIT' ? (_fee / 2).ceil() : 0);
    final sellerFee = _feePayer == 'SELLER' ? _fee : (_feePayer == 'SPLIT' ? (_fee / 2).floor() : 0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'BUAT RUANG REKBER',
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
        shape: const Border(bottom: BorderSide(color: Colors.black, width: 2.0)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peran Anda Dalam Transaksi',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildRoleOption('Penjual', Icons.storefront_rounded),
                const SizedBox(width: 12),
                _buildRoleOption('Pembeli', Icons.shopping_bag_rounded),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'Lawan Transaksi (Email / Username)',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            BrutalistTextField(
              hintText: 'Masukkan email atau username lawan',
              prefixIcon: Icons.alternate_email_rounded,
              controller: _opponentController,
            ),
            const SizedBox(height: 24),

            Text(
              'Deskripsi / Nama Barang',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            BrutalistTextField(
              hintText: 'Contoh: Akun Mobile Legends Mythic',
              prefixIcon: Icons.description_rounded,
              controller: _descController,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                return ActionChip(
                  label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  backgroundColor: AppColors.paleYellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.black, width: 1.5),
                  ),
                  onPressed: () => setState(() => _descController.text = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            Text(
              'Nominal Transaksi (Rp)',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            BrutalistTextField(
              hintText: 'Contoh: 500000',
              prefixIcon: Icons.payments_rounded,
              controller: _amountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            Text(
              'Tanggungan Biaya Platform (Fee Rekber)',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildFeePayerOption('BUYER', 'Pembeli'),
                const SizedBox(width: 8),
                _buildFeePayerOption('SELLER', 'Penjual'),
                const SizedBox(width: 8),
                _buildFeePayerOption('SPLIT', 'Dibagi Dua'),
              ],
            ),
            const SizedBox(height: 24),

            // Ringkasan kalkulasi
            BrutalistCard(
              backgroundColor: AppColors.paleYellow,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryRow('Harga Barang', CurrencyFormatter.format(_nominal)),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Total Fee Platform', CurrencyFormatter.format(_fee)),
                  const Divider(color: Colors.black, thickness: 1.5, height: 20),
                  _buildSummaryRow('Total Tagihan Pembeli', CurrencyFormatter.format(_nominal + buyerFee), isBold: true),
                  const SizedBox(height: 4),
                  _buildSummaryRow('Net Diterima Penjual', CurrencyFormatter.format(_nominal - sellerFee), isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 32),

            BlocBuilder<TransactionCubit, TransactionState>(
              builder: (context, state) {
                final isSubmitting = state is TransactionActionLoading;
                return BrutalistButton(
                  text: isSubmitting ? 'MEMBUAT RUANG...' : 'BUAT RUANG SEKARANG',
                  backgroundColor: AppColors.tealGreen,
                  textColor: Colors.black,
                  onPressed: isSubmitting ? () {} : _createRoom,
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(String role, IconData icon) {
    final isSelected = _peran == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _peran = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: isSelected ? null : const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.black, size: 20),
              const SizedBox(width: 8),
              Text(
                role,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeePayerOption(String value, String label) {
    final isSelected = _feePayer == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _feePayer = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: isSelected ? null : const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}
