import 'dart:io';

import 'data/image/image_crop_processor.dart';
import 'data/ml_kit/ml_kit_text_datasource.dart';
import 'domain/exceptions/nid_ocr_exception.dart';
import 'domain/models/nid_card.dart';
import 'domain/models/nid_scan_result.dart';
import 'domain/models/raw_nid_scan.dart';
import 'domain/nid_scan_parser.dart';

/// Framework-independent Bangladesh NID OCR facade.
///
/// This is the package's entire public entry point: a plain class with
/// `Future`-returning methods, no `Rx`/`ChangeNotifier`/state-management
/// dependency of any kind, and no navigation or UI. The consumer wraps
/// calls to it in whatever state management (or none) they use.
///
/// ```dart
/// final nidOcr = NidOcr();
/// final result = await nidOcr.scan(frontImage: front, backImage: back);
/// await nidOcr.dispose(); // must be called — releases ML Kit recognizers
/// ```
///
/// Front-OCR, back-OCR, and barcode-scan run concurrently via
/// `Future.wait`; text recognition of each image is sequential internally
/// (see [MLKitTextDataSource]). Failures surface as a thrown
/// [NidOcrException] rather than a `Result`/`Either` wrapper; `cropToViewport`
/// is the one exception — it falls back to the original image on any
/// failure rather than throwing (see below).
class NidOcr {
  final MLKitTextDataSource _dataSource;
  final ImageCropProcessor _imageProcessor;
  final NidScanParser _parser;

  /// Creates a new OCR session. Each instance owns its own ML Kit
  /// recognizers — call [dispose] exactly once when done with it.
  NidOcr({
    MLKitTextDataSource? dataSource,
    ImageCropProcessor? imageProcessor,
    NidScanParser? parser,
  }) : _dataSource = dataSource ?? MLKitTextDataSource(),
       _imageProcessor = imageProcessor ?? ImageCropProcessor(),
       _parser = parser ?? const NidScanParser();

  /// Runs OCR + barcode scanning on [frontImage]/[backImage] and parses the
  /// result into structured NID fields.
  ///
  /// Front-OCR, back-OCR, and barcode-scan run concurrently; if any of the
  /// three fails, this throws a [TextRecognitionException] or
  /// [BarcodeScanException] (whichever underlying call failed) rather than
  /// silently continuing.
  Future<NidScanResult> scan({
    required File frontImage,
    required File backImage,
  }) async {
    final raw = await _extractRaw(frontImage: frontImage, backImage: backImage);

    final NidCard card;
    try {
      card = _parser.parse(frontText: raw.frontText, backText: raw.backText);
    } catch (e) {
      // Not expected in normal operation — the parser returns null fields
      // rather than throwing. This is a defensive guard against a genuinely
      // unexpected internal error, not a routine "field not found" path.
      throw NidParsingException('Failed to parse NID fields', cause: e);
    }

    final barcodeData = raw.barcodeRaw != null
        ? _parser.parseBarcode(raw.barcodeRaw!)
        : <String, dynamic>{};

    return NidScanResult(card: card, barcodeData: barcodeData);
  }

  /// Runs ML Kit text recognition and barcode scanning on both images and
  /// returns the unparsed result, without running it through
  /// [NidScanParser].
  ///
  /// Exposed for consumers who want the raw OCR text (e.g. for debugging
  /// misreads) without paying for parsing, or who want to call
  /// [NidScanParser] separately.
  Future<RawNidScan> extractRaw({
    required File frontImage,
    required File backImage,
  }) => _extractRaw(frontImage: frontImage, backImage: backImage);

  Future<RawNidScan> _extractRaw({
    required File frontImage,
    required File backImage,
  }) async {
    final results = await Future.wait([
      _recognizeTextOrThrow(frontImage),
      _recognizeTextOrThrow(backImage),
      _scanBarcodeOrThrow(backImage),
    ]);

    return RawNidScan(
      frontText: results[0] ?? '',
      backText: results[1] ?? '',
      barcodeRaw: results[2],
    );
  }

  Future<String?> _recognizeTextOrThrow(File image) async {
    try {
      return await _dataSource.recognizeText(image);
    } catch (e) {
      throw TextRecognitionException(
        'Failed to recognize text on ${image.path}',
        cause: e,
      );
    }
  }

  Future<String?> _scanBarcodeOrThrow(File image) async {
    try {
      return await _dataSource.scanBarcode(image);
    } catch (e) {
      throw BarcodeScanException(
        'Failed to scan barcode on ${image.path}',
        cause: e,
      );
    }
  }

  /// Auto-crops [image] to the given viewport aspect ratio.
  ///
  /// **Never throws**: any failure (decode error, I/O error, or anything
  /// else) silently falls back to returning [image] unchanged. This makes
  /// cropping failures unobservable to the caller — flagged as a candidate
  /// for a future behavior change (see "Known limitations" in the README),
  /// not something to rely on.
  Future<File> cropToViewport({
    required File image,
    required double viewportWidth,
    required double viewportHeight,
  }) async {
    try {
      final cropped = await _imageProcessor.cropImage(
        image,
        viewportWidth,
        viewportHeight,
      );
      return cropped ?? image;
    } catch (_) {
      return image;
    }
  }

  /// Releases the ML Kit recognizers/scanner held by this instance. Must be
  /// called exactly once when this [NidOcr] is no longer needed (e.g. from
  /// whatever disposal hook the consumer's framework provides — `dispose()`,
  /// `onClose()`, `ref.onDispose()`, etc.).
  Future<void> dispose() async {
    await _dataSource.close();
  }
}
