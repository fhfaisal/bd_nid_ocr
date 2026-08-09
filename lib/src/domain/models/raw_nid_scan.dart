/// Unparsed OCR/barcode output for a front+back NID scan pair.
///
/// Exposed publicly (unlike Microzen's internal-only `RawNidScanEntity`) so
/// consumers debugging misreads can inspect exactly what ML Kit returned
/// before the parser normalized/extracted it — see `docs/ARCHITECTURE.md` §9.
class RawNidScan {
  /// Combined OCR text from the front image (Devanagari-script result,
  /// then Latin-script result, newline-joined — see [NidOcr.scan]).
  final String frontText;

  /// Combined OCR text from the back image, same format as [frontText].
  final String backText;

  /// Raw decoded payload of the PDF417 barcode on the back image, or `null`
  /// if no barcode was found.
  final String? barcodeRaw;

  const RawNidScan({
    required this.frontText,
    required this.backText,
    this.barcodeRaw,
  });

  @override
  String toString() =>
      'RawNidScan(frontText: $frontText, backText: $backText, '
      'barcodeRaw: $barcodeRaw)';
}
