// Ported from microzen/test/app/modules/MIS/scan_nid/data/repositories/
// nid_scan_repository_impl_test.dart's intent — same orchestration/fallback
// assertions, retargeted at the NidOcr facade (which replaces the
// repository+usecase split and dartz/Either with plain Futures/exceptions,
// see docs/ARCHITECTURE.md §6/§9/§13).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bd_nid_ocr/bd_nid_ocr.dart';
import 'package:bd_nid_ocr/src/data/image/image_crop_processor.dart';
import 'package:bd_nid_ocr/src/data/ml_kit/ml_kit_text_datasource.dart';
import 'package:mocktail/mocktail.dart';

class MockMLKitTextDataSource extends Mock implements MLKitTextDataSource {}

class MockImageCropProcessor extends Mock implements ImageCropProcessor {}

class FakeFile extends Fake implements File {}

void main() {
  late MockMLKitTextDataSource mockDataSource;
  late MockImageCropProcessor mockImageProcessor;
  late NidOcr nidOcr;

  setUpAll(() {
    registerFallbackValue(FakeFile());
  });

  setUp(() {
    mockDataSource = MockMLKitTextDataSource();
    mockImageProcessor = MockImageCropProcessor();
    nidOcr = NidOcr(
      dataSource: mockDataSource,
      imageProcessor: mockImageProcessor,
    );
  });

  group('NidOcr.scan', () {
    test(
      'runs OCR + barcode scanning on both images and parses the result',
      () async {
        final front = File('front.jpg');
        final back = File('back.jpg');
        when(
          () => mockDataSource.recognizeText(front),
        ).thenAnswer((_) async => 'Name: John Doe');
        when(
          () => mockDataSource.recognizeText(back),
        ).thenAnswer((_) async => 'Blood Group: A+');
        when(() => mockDataSource.scanBarcode(back)).thenAnswer(
          (_) async => '<pin>1234567890123</pin><name>John Doe</name>',
        );

        final result = await nidOcr.scan(frontImage: front, backImage: back);

        expect(result.card.name, 'John Doe');
        expect(result.card.bloodGroup, 'A+');
        expect(result.barcodeData['ID Number'], '1234567890123');
        expect(result.barcodeData['Full Name'], 'John Doe');
      },
    );

    test('returns an empty barcode map when no barcode was found', () async {
      final front = File('front.jpg');
      final back = File('back.jpg');
      when(
        () => mockDataSource.recognizeText(any()),
      ).thenAnswer((_) async => '');
      when(
        () => mockDataSource.scanBarcode(any()),
      ).thenAnswer((_) async => null);

      final result = await nidOcr.scan(frontImage: front, backImage: back);

      expect(result.barcodeData, isEmpty);
    });

    test(
      'throws TextRecognitionException when text recognition fails',
      () async {
        final front = File('front.jpg');
        final back = File('back.jpg');
        when(
          () => mockDataSource.recognizeText(any()),
        ).thenThrow(Exception('OCR failed'));
        when(
          () => mockDataSource.scanBarcode(any()),
        ).thenAnswer((_) async => null);

        expect(
          () => nidOcr.scan(frontImage: front, backImage: back),
          throwsA(isA<TextRecognitionException>()),
        );
      },
    );

    test('throws BarcodeScanException when barcode scanning fails', () async {
      final front = File('front.jpg');
      final back = File('back.jpg');
      when(
        () => mockDataSource.recognizeText(any()),
      ).thenAnswer((_) async => '');
      when(
        () => mockDataSource.scanBarcode(any()),
      ).thenThrow(Exception('barcode failed'));

      expect(
        () => nidOcr.scan(frontImage: front, backImage: back),
        throwsA(isA<BarcodeScanException>()),
      );
    });
  });

  group('NidOcr.cropToViewport', () {
    test('returns the cropped file on success', () async {
      final source = File('source.jpg');
      final cropped = File('cropped.jpg');
      when(
        () => mockImageProcessor.cropImage(source, 300, 240),
      ).thenAnswer((_) async => cropped);

      final result = await nidOcr.cropToViewport(
        image: source,
        viewportWidth: 300,
        viewportHeight: 240,
      );

      expect(result.path, 'cropped.jpg');
    });

    test(
      'falls back to the original image when the processor returns null',
      () async {
        final source = File('source.jpg');
        when(
          () => mockImageProcessor.cropImage(source, 300, 240),
        ).thenAnswer((_) async => null);

        final result = await nidOcr.cropToViewport(
          image: source,
          viewportWidth: 300,
          viewportHeight: 240,
        );

        expect(result.path, 'source.jpg');
      },
    );

    test('falls back to the original image when the processor throws '
        '(preserves the existing silent-fallback behavior, see '
        'docs/ARCHITECTURE.md §11/§15.5)', () async {
      final source = File('source.jpg');
      when(
        () => mockImageProcessor.cropImage(source, 300, 240),
      ).thenThrow(Exception('decode failed'));

      final result = await nidOcr.cropToViewport(
        image: source,
        viewportWidth: 300,
        viewportHeight: 240,
      );

      expect(result.path, 'source.jpg');
    });
  });

  group('NidOcr.dispose', () {
    test('closes the ML Kit data source', () async {
      when(() => mockDataSource.close()).thenAnswer((_) async {});

      await nidOcr.dispose();

      verify(() => mockDataSource.close()).called(1);
    });
  });
}
