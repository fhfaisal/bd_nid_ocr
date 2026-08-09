import 'nid_card.dart';

/// The result of [NidOcr.scan]: the parsed [NidCard] plus the decoded PDF417
/// barcode payload.
class NidScanResult {
  /// The structured fields extracted from OCR + MRZ.
  final NidCard card;

  /// The PDF417 barcode payload decoded into a key/value map. Keys and
  /// coverage are format-dependent (see `docs/ARCHITECTURE.md` §15.4) — the
  /// map is empty if no barcode was found or it could not be decoded.
  final Map<String, dynamic> barcodeData;

  const NidScanResult({required this.card, required this.barcodeData});

  @override
  String toString() => 'NidScanResult(card: $card, barcodeData: $barcodeData)';
}
