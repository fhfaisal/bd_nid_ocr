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
/// This is the package's entire public entry point (see
/// `docs/ARCHITECTURE.md` §9/§10): a plain class with `Future`-returning
/// methods, no `Rx`/`ChangeNotifier`/state-management dependency of any
/// kind, and no navigation or UI. The consumer wraps calls to it in
/// whatever state management (or none) they use.
///
/// ```dart
/// final nidOcr = NidOcr();
/// final result = await nidOcr.scan(frontImage: front, backImage: back);
/// await nidOcr.dispose(); // must be called — releases ML Kit recognizers
/// ```
///
/// Orchestration mirrors Microzen's `NIDScanRepositoryImpl.extractNidText` +
/// `ScanNIDUseCase.scanNid`/`cropToViewport` exactly (see
/// `docs/ARCHITECTURE.md` §5/§6): front-OCR, back-OCR, and barcode-scan run
/// concurrently via `Future.wait`; text recognition of each image is
/// sequential internally (see [MLKitTextDataSource]). `dartz`/`Either` are
/// replaced by [NidOcrException] thrown from `scan`; `cropToViewport`
/// preserves the original's silent fallback-to-original-image behavior on
/// any failure (see `docs/ARCHITECTURE.md` §11/§15.5) rather than throwing.
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
  /// Mirrors `ScanNIDUseCase.scanNid`. Front-OCR, back-OCR, and barcode-scan
  /// run concurrently; if any of the three fails, this throws a
  /// [TextRecognitionException] or [BarcodeScanException] (whichever
  /// underlying call failed — see `docs/ARCHITECTURE.md` §5) rather than
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
      // Not observed in the reference implementation — the parser returns
      // null fields rather than throwing (see docs/ARCHITECTURE.md §9). This
      // is a defensive guard against a genuinely unexpected internal error,
      // not a routine "field not found" path.
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
  /// misreads — see `docs/ARCHITECTURE.md` §9) without paying for parsing,
  /// or who want to call [NidScanParser] separately.
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
  /// Mirrors `ScanNIDUseCase.cropToViewport` exactly, including its current
  /// behavior of **never throwing**: any failure (decode error, I/O error,
  /// or anything else) silently falls back to returning [image] unchanged.
  /// This is preserved intentionally per the preserve-existing-behavior
  /// constraint even though it makes cropping failures unobservable to the
  /// caller — see `docs/ARCHITECTURE.md` §11/§15.5, which flags this as a
  /// candidate for a future (separately-approved) behavior change, not
  /// something to alter during extraction.
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
  /// `onClose()`, `ref.onDispose()`, etc. — see `docs/ARCHITECTURE.md` §10).
  Future<void> dispose() async {
    await _dataSource.close();
  }
}
