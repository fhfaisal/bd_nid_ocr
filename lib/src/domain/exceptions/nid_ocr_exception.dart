/// Base type for all errors thrown by `bd_nid_ocr`.
///
/// The package never wraps errors in `Either`/`Failure` (that was Microzen's
/// app-wide choice, not part of the OCR logic — see `docs/ARCHITECTURE.md`
/// §11/§13). It throws a small, purpose-built exception hierarchy instead,
/// so the package has zero dependency on `dartz` or any consumer's error
/// model.
sealed class NidOcrException implements Exception {
  final String message;

  /// The underlying error that triggered this exception, if any (e.g. a
  /// plugin-thrown `PlatformException` or `Exception` from `image`/ML Kit).
  final Object? cause;

  const NidOcrException(this.message, {this.cause});

  @override
  String toString() => cause == null
      ? '$runtimeType: $message'
      : '$runtimeType: $message (cause: $cause)';
}

/// ML Kit text recognition (front or back image) failed.
class TextRecognitionException extends NidOcrException {
  const TextRecognitionException(super.message, {super.cause});
}

/// ML Kit PDF417 barcode scanning failed.
class BarcodeScanException extends NidOcrException {
  const BarcodeScanException(super.message, {super.cause});
}

/// Unexpected failure while normalizing OCR text or extracting fields
/// (regex/MRZ parsing). Not observed in the reference implementation —
/// `NidScanParser` does not throw for missing fields, it returns nulls — so
/// this exists only for genuinely unexpected internal errors, not routine
/// "field not found" cases (see `docs/ARCHITECTURE.md` §9).
class NidParsingException extends NidOcrException {
  const NidParsingException(super.message, {super.cause});
}
