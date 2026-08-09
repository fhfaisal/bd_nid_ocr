// Same platform-channel mocking strategy as the original source
// implementation, retargeted at the package's MLKitTextDataSource. Mocks
// at the plugin-channel level (not the datasource itself), so this
// genuinely exercises MLKitTextDataSource's call sequencing under
// `flutter test`, no device/emulator needed — it is not a pure-Dart unit
// test, but it doesn't need to be an integration test either.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bd_nid_ocr/src/data/ml_kit/ml_kit_text_datasource.dart';

// google_mlkit_text_recognition/google_mlkit_barcode_scanning talk to the
// native side through these two named platform channels (see
// `TextRecognizer`/`BarcodeScanner` in the plugin sources) — mocking them
// here lets MLKitTextDataSource run under `flutter test` with no
// device/emulator.
const _textChannel = MethodChannel('google_mlkit_text_recognizer');
const _barcodeChannel = MethodChannel('google_mlkit_barcode_scanning');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(_textChannel, null);
    messenger.setMockMethodCallHandler(_barcodeChannel, null);
  });

  group('MLKitTextDataSource.recognizeText', () {
    test(
      'runs the latin then devanagari recognizer and concatenates devanagari-then-latin',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(_textChannel, (call) async {
          calls.add(call);
          final script = (call.arguments as Map)['script'] as int;
          // TextRecognitionScript.latin == 0, .devanagiri == 2.
          final text = script == 0 ? 'LATIN TEXT' : 'DEVANAGARI TEXT';
          return {'text': text, 'blocks': <dynamic>[]};
        });

        final result = await MLKitTextDataSource().recognizeText(
          File('front.jpg'),
        );

        expect(result, 'DEVANAGARI TEXT\nLATIN TEXT');
        // Processed sequentially (latin first) to avoid concurrent native
        // calls, per the implementation's comment.
        expect(calls.map((c) => (c.arguments as Map)['script']), [0, 2]);
      },
    );
  });

  group('MLKitTextDataSource.scanBarcode', () {
    Map<String, dynamic> barcodeJson(String rawValue) => {
      'type': 0,
      'format': 0,
      'displayValue': rawValue,
      'rawValue': rawValue,
      'rawBytes': null,
      'rect': <String, dynamic>{},
      'points': <dynamic>[],
    };

    test('returns the raw value of the first detected barcode', () async {
      messenger.setMockMethodCallHandler(_barcodeChannel, (call) async {
        if (call.method == 'vision#startBarcodeScanner') {
          return [barcodeJson('NID-RAW-VALUE')];
        }
        return null;
      });

      final result = await MLKitTextDataSource().scanBarcode(File('back.jpg'));

      expect(result, 'NID-RAW-VALUE');
    });

    test('returns null when no barcode is detected', () async {
      messenger.setMockMethodCallHandler(_barcodeChannel, (call) async {
        if (call.method == 'vision#startBarcodeScanner') {
          return <dynamic>[];
        }
        return null;
      });

      final result = await MLKitTextDataSource().scanBarcode(File('back.jpg'));

      expect(result, isNull);
    });
  });

  group('MLKitTextDataSource.close', () {
    test('closes both text recognizers and the barcode scanner', () async {
      final closedTextIds = <String>[];
      var barcodeClosed = false;

      messenger.setMockMethodCallHandler(_textChannel, (call) async {
        if (call.method == 'vision#closeTextRecognizer') {
          closedTextIds.add((call.arguments as Map)['id'] as String);
        }
        return null;
      });
      messenger.setMockMethodCallHandler(_barcodeChannel, (call) async {
        if (call.method == 'vision#closeBarcodeScanner') {
          barcodeClosed = true;
        }
        return null;
      });

      await MLKitTextDataSource().close();

      expect(closedTextIds.length, 2);
      expect(barcodeClosed, isTrue);
    });
  });
}
