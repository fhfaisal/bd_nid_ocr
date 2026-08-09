import 'dart:io';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Wraps the ML Kit text recognizers (Latin + Devanagari-as-Bengali) and the
/// PDF417 barcode scanner.
///
/// Text recognition within [recognizeText] runs sequentially, not
/// concurrently, to avoid concurrent native ML Kit calls on the same image.
/// This datasource itself does not run [recognizeText] and [scanBarcode]
/// concurrently with each other either — that orchestration (which *is*
/// concurrent, via `Future.wait`) lives one layer up, in [NidOcr.scan].
class MLKitTextDataSource {
  final TextRecognizer _latinRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  final TextRecognizer _devanagariRecognizer = TextRecognizer(
    script: TextRecognitionScript.devanagiri,
  );
  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.pdf417],
  );

  /// Runs both text recognizers over [image] sequentially and returns the
  /// Devanagari result followed by the Latin result, newline-joined.
  Future<String> recognizeText(File image) async {
    final inputImage = InputImage.fromFile(image);

    // Process sequentially to prevent potential native crashes
    final latinResult = await _latinRecognizer.processImage(inputImage);
    final devanagariResult = await _devanagariRecognizer.processImage(
      inputImage,
    );

    return '${devanagariResult.text}\n${latinResult.text}';
  }

  /// Scans [image] for a PDF417 barcode and returns its raw decoded value,
  /// or `null` if none was found.
  Future<String?> scanBarcode(File image) async {
    final inputImage = InputImage.fromFile(image);
    final barcodes = await _barcodeScanner.processImage(inputImage);

    if (barcodes.isNotEmpty) {
      return barcodes.first.rawValue;
    }
    return null;
  }

  /// Releases the native recognizer/scanner resources. Must be called
  /// exactly once when this datasource is no longer needed.
  Future<void> close() async {
    await _latinRecognizer.close();
    await _devanagariRecognizer.close();
    await _barcodeScanner.close();
  }
}
