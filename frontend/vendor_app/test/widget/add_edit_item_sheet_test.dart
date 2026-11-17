// test/widget/add_edit_item_sheet_test.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:brunchy_vendor/core/utils/image_helper.dart';
import 'package:brunchy_vendor/data/mock/mock_menu_repository.dart';
import 'package:brunchy_vendor/features/menu/menu_cubit.dart';
import 'package:brunchy_vendor/features/menu/widgets/add_edit_item_sheet.dart';

class TestImageHelper extends ImageHelper {
  final CompressedImageResult? resultToReturn;
  final bool simulateError;
  ImageSource? lastSource;

  TestImageHelper({
    this.resultToReturn,
    this.simulateError = false,
  });

  @override
  Future<CompressedImageResult?> pickAndCompressImage({
    required ImageSource source,
    required BuildContext context,
  }) async {
    lastSource = source;
    if (simulateError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid image data: unable to decode.')),
      );
      return null;
    }
    return resultToReturn;
  }
}

void main() {
  late MockMenuRepository mockRepo;
  late MenuCubit menuCubit;

  setUp(() async {
    mockRepo = MockMenuRepository();
    menuCubit = MenuCubit(mockRepo);
    await menuCubit.loadMenu('stall_001');
  });

  Widget buildTestWidget({ImageHelper? imageHelper}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AddEditItemSheet(
            menuCubit: menuCubit,
            imageHelper: imageHelper,
          ),
        ),
      ),
    );
  }

  testWidgets('Tapping photo square opens source selector with Camera and Gallery', (tester) async {
    await tester.pumpWidget(buildTestWidget());

    expect(find.text('Item Photo (WebP < 150KB)'), findsOneWidget);
    expect(find.text('Tap square to take or upload a photo'), findsOneWidget);

    // Tap the photo square container
    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();

    // Verify modal bottom sheet options are presented
    expect(find.text('Select Item Photo'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
  });

  testWidgets('Selecting Gallery picks image, shows preview and real compressed size', (tester) async {
    final sampleImg = img.Image(width: 50, height: 50);
    img.fill(sampleImg, color: img.ColorRgb8(255, 120, 0));
    final dummyBytes = Uint8List.fromList(img.encodePng(sampleImg));

    final testHelper = TestImageHelper(
      resultToReturn: CompressedImageResult(
        path: '/tmp/test_compressed.webp',
        bytes: dummyBytes,
        sizeInBytes: 86016, // 84 KB
      ),
    );

    await tester.pumpWidget(buildTestWidget(imageHelper: testHelper));

    // Tap photo square
    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();

    // Tap Choose from Gallery
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();

    expect(testHelper.lastSource, equals(ImageSource.gallery));
    expect(find.text('Photo selected & compressed to WebP (84 KB)'), findsOneWidget);
    expect(find.text('Image uploaded and compressed ✓'), findsOneWidget);
  });

  testWidgets('User cancelling picker results in no change and no crash', (tester) async {
    final testHelper = TestImageHelper(resultToReturn: null);

    await tester.pumpWidget(buildTestWidget(imageHelper: testHelper));

    // Tap photo square
    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();

    // Tap Take Photo
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();

    expect(testHelper.lastSource, equals(ImageSource.camera));
    // No change in status text
    expect(find.text('Tap square to take or upload a photo'), findsOneWidget);
    expect(find.text('Photo selected & compressed to WebP (84 KB)'), findsNothing);
  });

  testWidgets('Error during image reading/compression shows friendly message', (tester) async {
    final testHelper = TestImageHelper(simulateError: true);

    await tester.pumpWidget(buildTestWidget(imageHelper: testHelper));

    // Tap photo square
    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();

    // Tap Choose from Gallery
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid image data: unable to decode.'), findsOneWidget);
    expect(find.text('Tap square to take or upload a photo'), findsOneWidget);
  });
}
