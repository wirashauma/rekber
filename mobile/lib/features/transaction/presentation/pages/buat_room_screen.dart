import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../injection_container.dart';
import '../../../../core/services/api_service.dart';

class BuatRoomScreen extends StatefulWidget {
  const BuatRoomScreen({super.key});

  @override
  State<BuatRoomScreen> createState() => _BuatRoomScreenState();
}

class _BuatRoomScreenState extends State<BuatRoomScreen> {
  String _peran = 'Penjual'; // Penjual, Pembeli
  String _feePayer = 'Pembeli'; // Pembeli, Penjual, Dibagi Dua
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _opponentController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  double _nominal = 0;
  double _fee = 0;
  bool isLoading = false;
  bool _isSubmitting = false;

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
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateCalculations);
    _amountController.dispose();
    _opponentController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _updateCalculations() {
    setState(() {
      _nominal = double.tryParse(_amountController.text) ?? 0;
      _fee = _nominal * 0.02; // Flat 2% Rekber Fee
    });
  }

  Future<void> _createRoom() async {
    final opponentInput = _opponentController.text.trim();
    final descInput = _categoryController.text.trim();

    if (_nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal transaksi wajib diisi dan minimal Rp 1.000.')),
      );
      return;
    }
    if (opponentInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lawan transaksi wajib diisi.')),
      );
      return;
    }
    if (descInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori/deskripsi wajib diisi.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final apiService = sl<ApiService>();

      final searchRes = await apiService.get('/auth/search-opponent?query=$opponentInput');
      if (searchRes == null || searchRes['data'] == null || (searchRes['data'] as List).isEmpty) {
        throw ApiException(statusCode: 404, message: 'Lawan transaksi tidak ditemukan.');
      }

      final opponentId = searchRes['data'][0]['id'];

      final payload = {
        'amount': _nominal,
        'itemDescription': descInput,
        if (_peran == 'Pembeli') 'sellerId': opponentId,
        if (_peran == 'Penjual') 'buyerId': opponentId,
      };

      final txRes = await apiService.post('/transactions', payload);
      final newTxCode = txRes['data']['tx_code'] ?? txRes['data']['id'] ?? 'SUKSES';

      _showSuccessDialog(newTxCode);
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat transaksi: ${e.message}', style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan koneksi.', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: BrutalistCard(
          backgroundColor: AppColors.mustardYellow,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('RUANG REKBER BERHASIL DIBUAT! 🎉', 
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)
              ),
              const SizedBox(height: 20),
              const Text('Bagikan kode unik ini ke lawan transaksi Anda:', 
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: AppColors.black, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: AppColors.black, offset: Offset(4, 4)),
                  ],
                ),
                child: Center(
                  child: Text(
                    code,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              BrutalistButton(
                text: 'SALIN KODE',
                backgroundColor: AppColors.black,
                textColor: AppColors.white,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kode disalin ke clipboard!')),
                  );
                },
              ),
              const SizedBox(height: 12),
              BrutalistButton(
                text: 'TUTUP',
                backgroundColor: AppColors.white,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'INISIASI REKBER',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: AppColors.white,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.black, width: 2.0)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: isLoading 
          ? Column(
              children: List.generate(6, (index) => const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: BrutalSkeleton(width: double.infinity, height: 80),
              )),
            )
          : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Transaction Position
            Text('Posisi Anda', 
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16)
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildBrutalChip(
                  label: 'Sebagai Penjual',
                  isSelected: _peran == 'Penjual',
                  selectedColor: AppColors.tealGreen,
                  onTap: () => setState(() => _peran = 'Penjual'),
                ),
                const SizedBox(width: 12),
                _buildBrutalChip(
                  label: 'Sebagai Pembeli',
                  isSelected: _peran == 'Pembeli',
                  selectedColor: AppColors.tealGreen,
                  onTap: () => setState(() => _peran = 'Pembeli'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 2. Searchable Category
            Text('Kategori Transaksi', 
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16)
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                return _categories.where((String option) {
                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _categoryController.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return BrutalistTextField(
                  hintText: 'Cari kategori (e.g. Akun Game)',
                  prefixIcon: Icons.category_rounded,
                  controller: controller,
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: MediaQuery.of(context).size.width - 48,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(color: AppColors.black, width: 2.0),
                        boxShadow: const [
                          BoxShadow(color: AppColors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (context, index) => const Divider(color: AppColors.black, height: 1),
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 3. Price & Fee Bearer
            Text('Nominal Transaksi', 
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16)
            ),
            const SizedBox(height: 12),
            BrutalistTextField(
              hintText: 'Rp 0',
              prefixIcon: Icons.payments_rounded,
              controller: _amountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            Text('Penanggung Biaya Layanan', 
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16)
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildBrutalChip(
                  label: 'Pembeli',
                  isSelected: _feePayer == 'Pembeli',
                  selectedColor: AppColors.tealGreen,
                  onTap: () => setState(() => _feePayer = 'Pembeli'),
                  compact: true,
                ),
                const SizedBox(width: 8),
                _buildBrutalChip(
                  label: 'Penjual',
                  isSelected: _feePayer == 'Penjual',
                  selectedColor: AppColors.tealGreen,
                  onTap: () => setState(() => _feePayer = 'Penjual'),
                  compact: true,
                ),
                const SizedBox(width: 8),
                _buildBrutalChip(
                  label: '50:50',
                  isSelected: _feePayer == 'Dibagi Dua',
                  selectedColor: AppColors.tealGreen,
                  onTap: () => setState(() => _feePayer = 'Dibagi Dua'),
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Live Calculation Card
            if (_nominal > 0) ...[
              BrutalistCard(
                backgroundColor: Colors.yellow,
                borderWidth: 2.0,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildCalculationRow('Harga Barang', _nominal),
                    const SizedBox(height: 8),
                    _buildCalculationRow('Biaya Rekber (2%)', _fee),
                    const Divider(color: Colors.black, thickness: 2, height: 24),
                    _buildCalculationRow(
                      'Total Pembeli Bayar', 
                      _feePayer == 'Pembeli' ? _nominal + _fee : (_feePayer == 'Dibagi Dua' ? _nominal + (_fee / 2) : _nominal),
                      isBold: true,
                    ),
                    const SizedBox(height: 4),
                    _buildCalculationRow(
                      'Total Penjual Terima', 
                      _feePayer == 'Penjual' ? _nominal - _fee : (_feePayer == 'Dibagi Dua' ? _nominal - (_fee / 2) : _nominal),
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 4. Target User
            Text('Lawan Transaksi (Opsional)', 
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16)
            ),
            const SizedBox(height: 12),
            BrutalistTextField(
              hintText: 'Username atau Email',
              prefixIcon: Icons.person_search_rounded,
              controller: _opponentController,
            ),
            const SizedBox(height: 32),

            const SizedBox(height: 32),

            // 5. Action Button
            BrutalistButton(
              text: 'BUAT RUANG & GENERATE KODE',
              isLoading: _isSubmitting,
              backgroundColor: AppColors.tealGreen,
              onPressed: _isSubmitting ? () {} : _createRoom,
            ),
            const SizedBox(height: 80), 
          ],
        ),
      ),
    );
  }

  Widget _buildBrutalChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color selectedColor,
    bool compact = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : AppColors.white,
            border: Border.all(color: AppColors.black, width: 2.0),
            boxShadow: isSelected ? null : const [
              BoxShadow(color: AppColors.black, offset: Offset(4, 4)),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: compact ? 12 : 14,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalculationRow(String label, double value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            fontSize: isBold ? 14 : 13,
            color: Colors.black,
          ),
        ),
        Text(
          CurrencyFormatter.format(value.toInt()),
          style: GoogleFonts.spaceGrotesk(
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            fontSize: isBold ? 16 : 13,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}


