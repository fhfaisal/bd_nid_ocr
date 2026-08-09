/// Base type for all errors thrown by `bd_nid_ocr`.
///
/// The package throws a small, purpose-built exception hierarchy rather
/// than wrapping errors in a `Result`/`Either` type, so it has zero
/// dependency on any functional-error-handling package or the consumer's
/// own error model.
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
/// (regex/MRZ parsing). Not expected in normal operation — [NidScanParser]
/// does not throw for missing fields, it returns nulls — so this exists
/// only for genuinely unexpected internal errors, not routine "field not
/// found" cases.
class NidParsingException extends NidOcrException {
  const NidParsingException(super.message, {super.cause});
}
