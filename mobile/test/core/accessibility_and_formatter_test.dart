import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rekber/core/constants/app_colors.dart';
import 'package:rekber/core/constants/app_dimensions.dart';
import 'package:rekber/core/utils/currency_formatter.dart';
import 'package:rekber/core/utils/date_formatter.dart';
import 'package:rekber/core/widgets/brutalist_widgets.dart';
import 'package:rekber/core/widgets/rekber_button.dart';

/// Helper to compute relative luminance according to WCAG 2.1
double _relativeLuminance(Color color) {
  double transform(double c) {
    return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = transform(color.r);
  final g = transform(color.g);
  final b = transform(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Helper to compute WCAG 2.1 contrast ratio: (L1 + 0.05) / (L2 + 0.05)
double _contrastRatio(Color c1, Color c2) {
  final l1 = _relativeLuminance(c1);
  final l2 = _relativeLuminance(c2);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('A. Pemformatan Rupiah (CurrencyFormatter)', () {
    test('format nominal positif standar', () {
      final formatted = CurrencyFormatter.format(1500000);
      expect(formatted, contains('1.500.000'));
      expect(formatted, contains('Rp'));
    });

    test('format nominal 0', () {
      final formatted = CurrencyFormatter.format(0);
      expect(formatted, contains('0'));
      expect(formatted, contains('Rp'));
    });

    test('format nominal puluhan juta', () {
      final formatted = CurrencyFormatter.format(25750000);
      expect(formatted, contains('25.750.000'));
    });

    test('formatNoSymbol mengembalikan angka terformat tanpa Rp', () {
      final formatted = CurrencyFormatter.formatNoSymbol(1250000);
      expect(formatted, equals('1.250.000'));
      expect(formatted.contains('Rp'), isFalse);
    });

    test('formatCompact menghasilkan representasi ringkas', () {
      final compact = CurrencyFormatter.formatCompact(1500000);
      expect(compact.isNotEmpty, isTrue);
      expect(compact, contains('Rp'));
    });

    test('parse mengembalikan nilai integer yang benar', () {
      expect(CurrencyFormatter.parse('Rp 1.500.000'), equals(1500000));
      expect(CurrencyFormatter.parse('Rp1.500.000'), equals(1500000));
      expect(CurrencyFormatter.parse('250.000'), equals(250000));
      expect(CurrencyFormatter.parse(''), equals(0));
      expect(CurrencyFormatter.parse('tidak-ada-angka'), equals(0));
    });
  });

  group('B. Pemformatan Tanggal & Jam WIB (DateFormatter)', () {
    test('formatDate dalam Bahasa Indonesia', () {
      final dt = DateTime(2026, 5, 8);
      final formatted = DateFormatter.formatDate(dt);
      expect(formatted, equals('8 Mei 2026'));
    });

    test('formatDateShort dd/MM/yyyy', () {
      final dt = DateTime(2026, 5, 8);
      final formatted = DateFormatter.formatDateShort(dt);
      expect(formatted, equals('08/05/2026'));
    });

    test('formatDateTime menampilkan tanggal dan jam', () {
      final dt = DateTime(2026, 5, 8, 14, 30);
      final formatted = DateFormatter.formatDateTime(dt);
      expect(formatted, equals('8 Mei 2026, 14:30'));
    });

    test('formatTime hanya menampilkan HH:mm', () {
      final dt = DateTime(2026, 5, 8, 9, 5);
      final formatted = DateFormatter.formatTime(dt);
      expect(formatted, equals('09:05'));
    });

    test('Pergantian hari dari UTC ke WIB (UTC+7)', () {
      // 1 Mei 2026 pukul 23:30 UTC -> WIB (UTC+7) = 2 Mei 2026 pukul 06:30
      final utcTime = DateTime.utc(2026, 5, 1, 23, 30);
      final wibTime = utcTime.toUtc().add(const Duration(hours: 7));

      expect(wibTime.day, equals(2));
      expect(wibTime.month, equals(5));
      expect(wibTime.year, equals(2026));
      expect(wibTime.hour, equals(6));
      expect(wibTime.minute, equals(30));

      final formattedWib = DateFormatter.formatDateTime(wibTime);
      expect(formattedWib, equals('2 Mei 2026, 06:30'));
    });

    test('Pergantian tahun/bulan dari UTC ke WIB (UTC+7)', () {
      // 31 Des 2026 pukul 20:00 UTC -> WIB (UTC+7) = 1 Jan 2027 pukul 03:00
      final utcTime = DateTime.utc(2026, 12, 31, 20, 0);
      final wibTime = utcTime.toUtc().add(const Duration(hours: 7));

      expect(wibTime.year, equals(2027));
      expect(wibTime.month, equals(1));
      expect(wibTime.day, equals(1));
      expect(wibTime.hour, equals(3));

      final formattedWib = DateFormatter.formatDate(wibTime);
      expect(formattedWib, equals('1 Januari 2027'));
    });
  });

  group('C. Aksesibilitas: Ukuran Target Sentuh (Touch Target >= 48dp)', () {
    test('AppDimensions.buttonHeight memenuhi standar >= 48dp', () {
      expect(AppDimensions.buttonHeight, greaterThanOrEqualTo(48.0));
      expect(AppDimensions.inputHeight, greaterThanOrEqualTo(48.0));
    });

    testWidgets('BrutalistButton memiliki tinggi >= 48dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrutalistButton(
              text: 'BAYAR SEKARANG',
              onPressed: () {},
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(BrutalistButton);
      expect(buttonFinder, findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('RekberButton memiliki tinggi >= 48dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RekberButton(
              text: 'LANJUTKAN',
              onPressed: () {},
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(RekberButton);
      expect(buttonFinder, findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('D. Aksesibilitas: Label Semantics untuk Tombol Utama', () {
    testWidgets('BrutalistButton memiliki semantics label teks tombol', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrutalistButton(
              text: 'KONFIRMASI PESANAN',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('KONFIRMASI PESANAN'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('RekberButton memiliki semantics label teks tombol', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RekberButton(
              text: 'TOP UP SALDO',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('TOP UP SALDO'), findsOneWidget);
      handle.dispose();
    });
  });

  group('E. Aksesibilitas: Kontras Teks Tombol Utama (WCAG AA)', () {
    test('Tombol Primer Deep Purple: Teks Putih di atas Deep Purple (#6236FF)', () {
      final ratio = _contrastRatio(AppColors.white, AppColors.deepPurple);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Tombol Aksen Mustard Yellow: Teks Hitam di atas Kuning (#FFD500)', () {
      final ratio = _contrastRatio(AppColors.black, AppColors.mustardYellow);
      expect(ratio, greaterThanOrEqualTo(4.5));
      expect(ratio, greaterThan(12.0));
    });

    test('Tombol Sekunder: Teks Putih di atas Hitam (#000000)', () {
      final ratio = _contrastRatio(AppColors.white, AppColors.black);
      expect(ratio, greaterThanOrEqualTo(4.5));
      expect(ratio, equals(21.0));
    });

    test('Tombol Danger / Error: Teks Putih di atas Merah (#E74C3C) memenuhi WCAG AA Tombol Bold (>= 3.0:1)', () {
      final ratio = _contrastRatio(AppColors.white, AppColors.error);
      expect(ratio, greaterThanOrEqualTo(3.0));
    });
  });
}
