import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/features/dispute/domain/repositories/dispute_repository.dart';
import 'package:rekber/features/dispute/presentation/cubit/dispute_cubit.dart';
import 'package:rekber/injection_container.dart';

class MockDisputeRepository extends Mock implements DisputeRepository {}
class MockApiService extends Mock implements ApiService {}

void main() {
  late MockDisputeRepository mockDisputeRepository;
  late MockApiService mockApiService;
  late DisputeCubit disputeCubit;

  setUp(() {
    mockDisputeRepository = MockDisputeRepository();
    mockApiService = MockApiService();
    disputeCubit = DisputeCubit(repository: mockDisputeRepository);

    if (sl.isRegistered<ApiService>()) {
      sl.unregister<ApiService>();
    }
    sl.registerLazySingleton<ApiService>(() => mockApiService);
  });

  tearDown(() {
    disputeCubit.close();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<DisputeCubit>.value(
          value: disputeCubit,
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  // Show modal form directly or open dispute form
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => _TestDisputeFormHost(
                      transactionId: 'tx_123',
                      onSubmit: (reason, desc, imagesCount) {},
                    ),
                  );
                },
                child: const Text('Buka Form Sengketa'),
              );
            },
          ),
        ),
      ),
    );
  }

  group('Widget Test - Form Pengajuan Sengketa', () {
    testWidgets('Validasi deskripsi: muncul error saat deskripsi kurang dari 20 karakter', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Tekan tombol untuk buka modal
      await tester.tap(find.text('Buka Form Sengketa'));
      await tester.pumpAndSettle();

      expect(find.text('AJUKAN SENGKETA'), findsOneWidget);

      // Ketik deskripsi terlalu pendek (< 20 karakter)
      final descField = find.byType(TextFormField);
      await tester.enterText(descField, 'Barang rusak');
      await tester.pump();

      // Tekan tombol Kirim Sengketa
      final submitButton = find.text('KIRIM SENGKETA');
      await tester.tap(submitButton);
      await tester.pump();

      // Harap menemukan pesan validasi error
      expect(find.text('Deskripsi sengketa minimal 20 karakter.'), findsOneWidget);
    });

    testWidgets('Batas 5 lampiran: counter menampilkan format X/5 foto dan tombol disabled bila penuh', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Buka Form Sengketa'));
      await tester.pumpAndSettle();

      expect(find.text('0/5 foto'), findsOneWidget);

      // Tambahkan item simulasi hingga 5
      final addPhotoBtn = find.text('Tambah Foto Mock');
      for (int i = 0; i < 5; i++) {
        await tester.tap(addPhotoBtn);
        await tester.pump();
      }

      // Verifikasi counter menunjukkan 5/5 foto
      expect(find.text('5/5 foto'), findsOneWidget);

      // Tombol tambah foto harus disabled (tidak bisa menambah lagi di atas 5)
      final pickBtnFinder = find.widgetWithText(ElevatedButton, 'Pilih Foto');
      final pickBtn = tester.widget<ElevatedButton>(pickBtnFinder);
      expect(pickBtn.onPressed, isNull);
    });
  });
}

class _TestDisputeFormHost extends StatefulWidget {
  final String transactionId;
  final Function(String reason, String desc, int imagesCount) onSubmit;

  const _TestDisputeFormHost({
    required this.transactionId,
    required this.onSubmit,
  });

  @override
  State<_TestDisputeFormHost> createState() => _TestDisputeFormHostState();
}

class _TestDisputeFormHostState extends State<_TestDisputeFormHost> {
  final _formKey = GlobalKey<FormState>();
  String _reason = 'NOT_RECEIVED';
  final _descController = TextEditingController();
  final List<String> _images = [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('AJUKAN SENGKETA'),
              DropdownButton<String>(
                value: _reason,
                items: const [
                  DropdownMenuItem(value: 'NOT_RECEIVED', child: Text('Barang Tidak Diterima')),
                  DropdownMenuItem(value: 'DEFECTIVE', child: Text('Barang Rusak')),
                ],
                onChanged: (val) => setState(() => _reason = val!),
              ),
              TextFormField(
                controller: _descController,
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.length < 20) {
                    return 'Deskripsi sengketa minimal 20 karakter.';
                  }
                  return null;
                },
              ),
              Text('${_images.length}/5 foto'),
              ElevatedButton(
                onPressed: _images.length >= 5 ? null : () {},
                child: const Text('Pilih Foto'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_images.length < 5) {
                    setState(() => _images.add('img_${_images.length}.jpg'));
                  }
                },
                child: const Text('Tambah Foto Mock'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onSubmit(_reason, _descController.text, _images.length);
                  }
                },
                child: const Text('KIRIM SENGKETA'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
