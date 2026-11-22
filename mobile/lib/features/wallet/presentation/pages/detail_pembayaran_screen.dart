import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../cubit/wallet_cubit.dart';
import '../../domain/entities/payment_intent_entity.dart';

class DetailPembayaranScreen extends StatefulWidget {
  final dynamic data; // Menerima PaymentIntentEntity atau Map

  const DetailPembayaranScreen({super.key, required this.data});

  @override
  State<DetailPembayaranScreen> createState() => _DetailPembayaranScreenState();
}

class _DetailPembayaranScreenState extends State<DetailPembayaranScreen> {
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  Duration _remainingDuration = const Duration(hours: 24);
  bool _isSuccessDialogShown = false;
  PaymentIntentEntity? _currentIntent;

  @override
  void initState() {
    super.initState();
    _initData();
    _startCountdown();
    _startPolling();
  }

  void _initData() {
    if (widget.data is PaymentIntentEntity) {
      _currentIntent = widget.data as PaymentIntentEntity;
    } else if (widget.data is Map<String, dynamic>) {
      final map = widget.data as Map<String, dynamic>;
      _currentIntent = PaymentIntentEntity(
        id: map['id']?.toString() ?? '',
        provider: map['provider']?.toString() ?? 'XENDIT',
        referenceId: map['referenceId']?.toString() ?? '',
        amount: int.tryParse(map['amount']?.toString() ?? map['nominal']?.toString() ?? '0') ?? 0,
        method: map['method']?.toString() ?? 'QRIS',
        status: map['status']?.toString() ?? 'PENDING',
        qrString: map['qrString']?.toString(),
        vaNumber: map['vaNumber']?.toString(),
        bankCode: map['bankCode']?.toString(),
        expiresAt: map['expiresAt'] != null ? DateTime.tryParse(map['expiresAt'].toString()) : null,
        paidAt: null,
        createdAt: DateTime.now(),
      );
    }
  }

  void _startCountdown() {
    if (_currentIntent?.expiresAt != null) {
      _remainingDuration = _currentIntent!.expiresAt!.difference(DateTime.now());
      if (_remainingDuration.isNegative) _remainingDuration = Duration.zero;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingDuration.inSeconds > 0) {
        if (mounted) {
          setState(() {
            _remainingDuration -= const Duration(seconds: 1);
          });
        }
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  void _startPolling() {
    // Polling setiap 5 detik
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final intentId = _currentIntent?.id;
      if (intentId == null || intentId.isEmpty) return;

      final updated = await context.read<WalletCubit>().checkTopUpStatus(intentId);
      if (updated != null && mounted) {
        setState(() {
          _currentIntent = updated;
        });

        if (updated.isPaid && !_isSuccessDialogShown) {
          _isSuccessDialogShown = true;
          _pollingTimer?.cancel();
          _showSuccessDialog();
        }
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.tealGreen,
            border: Border.all(color: Colors.black, width: 4.0),
            boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(8, 8))],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 72, color: Colors.black),
              const SizedBox(height: 20),
              Text(
                'PEMBAYARAN DITERIMA! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Saldo sebesar ${CurrencyFormatter.format(_currentIntent?.amount ?? 0)} telah berhasil ditambahkan ke dompet Anda.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 28),
              BrutalistButton(
                text: 'KEMBALI KE BERANDA',
                backgroundColor: Colors.black,
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/home');
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
    final intent = _currentIntent;
    final isQris = intent?.method.toUpperCase() == 'QRIS';
    final amount = intent?.amount ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'DETAIL PEMBAYARAN',
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
          children: [
            // Timer Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.paleYellow,
                border: Border.all(color: Colors.black, width: 2.5),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_filled_rounded, color: Colors.black, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Selesaikan Pembayaran Dalam:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(
                          _formatDuration(_remainingDuration),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nominal Card
            BrutalistCard(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.format(amount),
                    style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment method detail: QRIS or Virtual Account
            if (isQris) ...[
              BrutalistCard(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'SCAN QRIS UNTUK MEMBAYAR',
                      style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (intent?.qrString != null && intent!.qrString!.isNotEmpty) ...[
                      QrImageView(
                        data: intent.qrString!,
                        version: QrVersions.auto,
                        size: 220.0,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.black),
                        label: const Text('Salin String QRIS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: intent.qrString!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('String QRIS disalin!')),
                          );
                        },
                      ),
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: Colors.black),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Buka aplikasi BCA, Mandiri, GoPay, OVO, DANA, atau ShopeePay Anda, lalu scan kode QR di atas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Virtual Account
              BrutalistCard(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOMOR VIRTUAL ACCOUNT (${intent?.bankCode ?? 'BANK'})',
                      style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.paleYellow,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              intent?.vaNumber ?? 'Sedang memuat...',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: () {
                              if (intent?.vaNumber != null) {
                                Clipboard.setData(ClipboardData(text: intent!.vaNumber!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Nomor VA disalin!')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Transfer tepat sesuai nominal yang tertera melalui ATM, Mobile Banking, atau Internet Banking.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Status Polling Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Text(
                  'Menunggu konfirmasi pembayaran dari sistem...',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
