import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/features/admin/domain/repositories/admin_repository.dart';
import 'package:rekber/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:rekber/features/admin/presentation/pages/admin_dispute_screen.dart';

class MockAdminRepository extends Mock implements AdminRepository {}

void main() {
  late MockAdminRepository mockAdminRepository;
  late AdminCubit adminCubit;

  setUp(() {
    mockAdminRepository = MockAdminRepository();
    adminCubit = AdminCubit(adminRepository: mockAdminRepository);
  });

  tearDown(() {
    adminCubit.close();
  });

  Widget createWidgetUnderTest() {
    return BlocProvider<AdminCubit>.value(
      value: adminCubit,
      child: const MaterialApp(
        home: AdminDisputeScreen(),
      ),
    );
  }

  testWidgets('Dispute resolution dialog requires mandatory note of at least 10 characters',
      (tester) async {
    // 1. Arrange disputes list
    final tDispute = {
      'id': 'disp-999',
      'transactionId': 'TX-1234',
      'reason': 'NOT_RECEIVED',
      'description': 'Barang tidak kunjung sampai setelah batas waktu.',
      'status': 'OPEN',
      'transaction': {
        'code': 'TRX-1234',
        'amount': 500000,
        'buyer': {'name': 'Budi'},
        'seller': {'name': 'Siti'},
      },
    };

    when(() => mockAdminRepository.getDisputes(
          status: any(named: 'status'),
          page: any(named: 'page'),
        )).thenAnswer((_) async => Right({
          'data': [tDispute]
        }));

    // 2. Pump widget and wait for dispute to render
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PUTUSKAN'), findsOneWidget);

    // 3. Tap 'PUTUSKAN' button to open resolution dialog
    await tester.tap(find.text('PUTUSKAN'));
    await tester.pumpAndSettle();

    expect(find.text('PUTUSAN SENGKETA'), findsOneWidget);
    expect(find.text('LANGKAH 1: PILIH PEMENANG'), findsOneWidget);
    expect(find.text('LANGKAH 2: CATATAN PUTUSAN (WAJIB)'), findsOneWidget);

    // 4. Try submitting with empty note
    final submitButton = find.text('EKSEKUSI PUTUSAN');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify validation error is shown
    expect(find.text('Catatan putusan wajib diisi.'), findsOneWidget);
    verifyNever(() => mockAdminRepository.resolveDispute(
          any(),
          decision: any(named: 'decision'),
          note: any(named: 'note'),
        ));

    // 5. Try submitting with note < 10 characters
    final noteField = find.byType(TextFormField);
    await tester.enterText(noteField, 'pendek');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Catatan minimal 10 karakter (saat ini 6).'), findsOneWidget);
    verifyNever(() => mockAdminRepository.resolveDispute(
          any(),
          decision: any(named: 'decision'),
          note: any(named: 'note'),
        ));

    // 6. Enter valid note >= 10 characters and submit
    when(() => mockAdminRepository.resolveDispute(
          'disp-999',
          decision: any(named: 'decision'),
          note: 'Barang terbukti telah sampai sesuai resi pengiriman.',
        )).thenAnswer((_) async => const Right({'status': 'RESOLVED_SELLER'}));

    await tester.enterText(
      noteField,
      'Barang terbukti telah sampai sesuai resi pengiriman.',
    );
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify resolve was called with valid parameters
    verify(() => mockAdminRepository.resolveDispute(
          'disp-999',
          decision: 'RELEASE_TO_SELLER',
          note: 'Barang terbukti telah sampai sesuai resi pengiriman.',
        )).called(1);
  });
}
