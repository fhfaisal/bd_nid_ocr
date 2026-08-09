/// Framework-agnostic Bangladesh NID (National ID) card OCR.
///
/// `bd_nid_ocr` owns: image cropping, ML Kit text/barcode recognition,
/// and regex/MRZ-based structured field extraction. It owns nothing about
/// state management, navigation, persistence, or UI — that stays entirely
/// in the consuming app.
///
/// This file is the package's entire public surface. Internals under
/// `src/data` (ML Kit / image-plugin wrappers) are not exported — consume
/// them only through [NidOcr]. [NidScanParser] is exported on its own
/// despite being an internal of [NidOcr.scan], because it is pure Dart with
/// no plugin dependency and is independently useful/testable for consumers
/// who already have raw OCR text (e.g. captured via their own pipeline, or
/// replayed from a saved fixture) and want structured fields without going
/// through image capture or ML Kit at all.
library;

export 'src/domain/exceptions/nid_ocr_exception.dart';
export 'src/domain/models/nid_card.dart';
export 'src/domain/models/nid_scan_result.dart';
export 'src/domain/models/raw_nid_scan.dart';
export 'src/domain/nid_scan_parser.dart';
export 'src/nid_ocr.dart';
